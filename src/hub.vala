/* Copyright 2024-2029
 * This file is part of ScrapperD.
 *
 * ScrapperD is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * ScrapperD is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with ScrapperD. If not, see <http://www.gnu.org/licenses/>.
 */
using Kademlia;

[CCode (cprefix = "KDBus", lower_case_cprefix = "kdbus_")]

namespace KademliaDBus
{
  public class Hub : GLib.Object
    {
      public const uint16 DEFAULT_PORT = 33334;

      private bool cached = true;
      private GLib.HashTable<Key, GLib.DBusConnection> cached_connections;
      private GLib.HashTable<Key, GLib.SList<string>> cached_public_addresses;
      private GLib.ThreadPool<GLib.SocketConnection> incomming_pool;
      private GLib.HashTable<void*, uint> nodes;
      private GLib.HashTable<string, KademliaDBus.Peer> peers;
      private GLib.SList<string> public_addresses;
      private GLib.SocketService socket_service;

      public uint16 port { get; construct; default = DEFAULT_PORT; }

      construct
        {
          unowned GLib.HashFunc<Key> hash_func = Key.hash;
          unowned GLib.EqualFunc<Key> equal_func = Key.equal;

          cached_connections = new HashTable<Key, DBusConnection> (hash_func, equal_func);
          cached_public_addresses = new HashTable<Key, SList<string>> (hash_func, equal_func);
          nodes = new HashTable<void*, uint> (GLib.direct_hash, GLib.direct_equal);
          peers = new HashTable<string, KademliaDBus.Peer> (GLib.str_hash, GLib.str_equal);
          public_addresses = new SList<string> ();
          socket_service = new SocketService ();

          socket_service.stop ();

          var exclusive = false;
          var max_threads = (int) GLib.get_num_processors ();

          try { incomming_pool = new GLib.ThreadPool<SocketConnection>.with_owned_data (on_incomming, max_threads, exclusive); } catch (GLib.Error e)
            {
              error (@"$(e.domain): $(e.code): $(e.message)");
            }

          socket_service.incoming.connect ((connection) =>
            {
              try { incomming_pool.add (connection); } catch (GLib.Error e)
                {
                  critical (@"$(e.domain): $(e.code): $(e.message)");
                }
              return true;
            });

          var localhost = new InetSocketAddress []
            {
              new InetSocketAddress (new InetAddress.loopback (GLib.SocketFamily.IPV4), port),
              new InetSocketAddress (new InetAddress.loopback (GLib.SocketFamily.IPV6), port),
            };

          foreach (unowned var address in localhost)
            {
              var protocol = GLib.SocketProtocol.DEFAULT;
              var type = GLib.SocketType.STREAM;

              public_addresses.prepend (address.to_string ());

              try { socket_service.add_address (address, type, protocol, address, null); } catch (GLib.Error e)
                {
                  critical (@"$(e.domain): $(e.code): $(e.message)");
                  continue;
                }
            }
        }

      public Hub (uint16 port = DEFAULT_PORT)
        {
          Object (port : port);
        }

      ~Hub ()
        {
          var peer = (KademliaDBus.Peer) null;
          var iter = HashTableIter<string, Peer> (peers);

          while (iter.next (null, out peer)) peer.register_on_hub (null);
        }

      public void add_peer (Peer peer)
        {
          peers.insert (peer.role, peer);
          peer.register_on_hub (this);
        }

      public async void add_public_address (string hostname) throws GLib.Error
        {
          var resolver = GLib.Resolver.get_default ();

          foreach (unowned var inet_address in yield resolver.lookup_by_name_async (hostname))
            {
              var address = new GLib.InetSocketAddress (inet_address, port);
              var protocol = GLib.SocketProtocol.TCP;
              var type = GLib.SocketType.STREAM;

              socket_service.add_address (address, type, protocol, address, null);
              public_addresses.prepend (hostname);
            }
        }

      public string[] addresses_for_peer (Key key)
        {
          lock (cached)
            {
              unowned var addrs = cached_public_addresses.lookup (key);
              var ar = (string[]) new string [addrs.length ()];
              int i = 0;
              foreach (unowned var addr in addrs) ar [i++] = addr;
              return (owned) ar;
            }
        }

      public void begin ()
        {
          socket_service.start ();
        }

      public async bool connect_to (string address, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var flags1 = GLib.DBusConnectionFlags.AUTHENTICATION_CLIENT;
          var flags2 = GLib.DBusConnectionFlags.DELAY_MESSAGE_PROCESSING;
          var flags = flags1 | flags2;
          var remote = (string?) null;
          var stream = (SocketConnection) yield (new SocketClient ()).connect_to_host_async (address, DEFAULT_PORT, cancellable);

          try { remote = stream.get_remote_address ().to_string (); } catch { }

          if (remote == null)
            debug ("connected to peer");
          else
            debug ("connected to peer (%s)", remote);

          var connection = (DBusConnection) yield new DBusConnection (stream, null, flags, null, null);

          if (remote == null)
            debug ("DBus created for connection");
          else
            debug ("DBus created for connection (%s)", remote);

          prepare_connection (connection);

          connection.exit_on_close = false;
          connection.on_closed.connect ((c, a, b) => on_closed (c));
          connection.start_message_processing ();

          return yield register_connection (connection, false, cancellable);
        }

      public async bool finish (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          socket_service.stop ();
          socket_service.close ();

          return yield forget_all (cancellable);
        }

      public async bool forget (Key key, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          GLib.DBusConnection connection;
          lock (cached) connection = cached_connections.lookup (key);

          if (connection != null)

            yield connection.close (cancellable);

          return true;
        }

      public async bool forget_all (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var connections = new SList<GLib.DBusConnection> ();

          lock (cached)
            {
              var connection = (DBusConnection) null;
              var iterator = HashTableIter<Key, GLib.DBusConnection> (cached_connections);

              while (iterator.next (null, out connection))

                connections.prepend ((owned) connection);
            }

          foreach (unowned var connection in connections)

            yield connection.close (cancellable);

          return true;
        }

      public string[] get_public_addresses ()
        {
          var ar = new string [public_addresses.length ()];
          int i = 0;
          foreach (unowned var item in public_addresses) ar [i++] = item;
          return (owned) ar;
        }

      public async T? get_proxy<T> (Key key, string role, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          GLib.DBusConnection connection;
          debug ("creating proxy for peer %s:%s", role, key.to_string ());

          while (true)
            {
              lock (cached) connection = cached_connections.lookup (key);

              if (likely (connection != null))
                {
                  debug ("using cached connection for peer %s:%s", role, key.to_string ());

                  Key key2;
                  string object_path;

                  object_path = Node.BASE_PATH;
                  var node = yield connection.get_proxy<Node> (null, object_path, 0, cancellable);

                  if ((role in node.Roles) == false)
                    {
                      debug ("no role on peer %s:%s", role, key.to_string ());
                      throw new Kademlia.PeerError.UNREACHABLE ("no role %s in node %s", role, key.to_string ());
                    }

                  object_path = @"$object_path/$role";
                  var node_role = yield connection.get_proxy<NodeRole> (null, object_path, 0, cancellable);

                  if (Key.equal (key, (key2 = new Key.verbatim (node_role.Id))))

                    return yield connection.get_proxy<T> (null, object_path, 0, cancellable);
                  else
                    {
                      debug ("resetted peer %s:%s", role, key.to_string ());

                      yield forget (key2, cancellable);
                      lock (cached) cached_public_addresses.remove (key2);
                      throw new Kademlia.PeerError.UNREACHABLE ("can not locate node %s", key.to_string ());
                    }
                }
              else
                {
                  debug ("don't have a cached connection for peer %s:%s", role, key.to_string ());

                  GLib.SList<string> addresses;
                  bool found = false;

                  lock (cached) addresses = cached_public_addresses.lookup (key).copy_deep ((s) => s);

                  foreach (unowned var address in addresses) try
                    {
                      debug ("connecting to peer %s:%s (%s)", role, key.to_string (), address);
                      found = yield connect_to (address, cancellable);
                      break;
                    }
                  catch (GLib.Error e)
                    {
                      warning (@"$(e.domain): $(e.code): $(e.message)");

                      addresses.remove (address);

                      if (addresses.length () == 0)

                        lock (cached) cached_public_addresses.remove (key);
                      else
                        {
                          var @new = addresses.copy_deep ((s) => s);
                          lock (cached) cached_public_addresses.insert (key.copy (), (owned) @new);
                        }
                      continue;
                    }

                  if (found == false)
                    {
                      debug ("can not connect to peer %s:%s", role, key.to_string ());
                      throw new Kademlia.PeerError.UNREACHABLE ("can not locate node %s", key.to_string ());
                    }
                }
            }
        }

      public async bool join (string address, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          Key[] keys;

          yield connect_to (address, cancellable);

          lock (cached)
            {
              var items = (List<unowned Key>) cached_public_addresses.get_keys ();
              var ar = new Key [items.length ()];
              int i = 0;

              foreach (unowned var item in items) ar [i++] = item.copy ();
              keys = (owned) ar;
            }

          foreach (unowned var peer in peers.get_values ())
            {
              foreach (unowned var key in keys) yield peer.join (key, cancellable);
            }

          return true;
        }

      public void known_peer (Key key, string[] public_addresses)
        {
          lock (cached)
            {
              var @set = new GenericSet<string> (GLib.str_hash, GLib.str_equal);

              foreach (unowned var addr in cached_public_addresses.lookup (key)) @set.add (addr);
              foreach (unowned var addr in public_addresses) @set.add (addr);

              var item = (string?) null;
              var iter = (GenericSetIter<string>) @set.iterator ();
              var list = new GLib.SList<string> ();

              while ((item = iter.next_value ()) != null) list.prepend ((owned) item);

              cached_public_addresses.insert (key.copy (), (owned) list);
            }
        }

      void on_closed (GLib.DBusConnection connection)
        {
          var id = (uint) 0;
          var peer = (KademliaDBus.Peer) null;
          var iter = HashTableIter<string, KademliaDBus.Peer> (peers);

          while (iter.next (null, out peer))
           
            peer.unregister_on_connection (connection);

          lock (cached) cached_connections.foreach_remove ((k, c) => c == connection);
          lock (nodes) id = nodes.lookup (connection);

          connection.unregister_object (id);
        }

      void on_incomming (owned GLib.SocketConnection connection)
        {
          string? remote = null;
          try { remote = connection.get_remote_address ().to_string (); } catch { }

          if (remote == null)

            debug ("incomming connection");
          else
            debug ("incomming connection (%s)", remote);

          on_incomming_async.begin ((owned) connection, (owned) remote, null, (o, res) =>
            {
              try { ((Hub) o).on_incomming_async.end (res); } catch (GLib.Error e)
                {
                  critical (@"$(e.domain): $(e.code): $(e.message)");
                }
            });
        }

      async bool on_incomming_async (owned GLib.SocketConnection stream, owned string? remote, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var flags1 = GLib.DBusConnectionFlags.AUTHENTICATION_ALLOW_ANONYMOUS;
          var flags2 = GLib.DBusConnectionFlags.AUTHENTICATION_SERVER;
          var flags3 = GLib.DBusConnectionFlags.DELAY_MESSAGE_PROCESSING;
          var flags = flags1 | flags2 | flags3;
          var guid = (string) DBus.generate_guid ();
          var connection = yield new DBusConnection (stream, guid, flags, null, null);

          if (remote == null)

            debug ("DBus created for connection");
          else
            debug ("DBus created for connection (%s)", remote);

          prepare_connection (connection, cancellable);

          connection.exit_on_close = false;
          connection.on_closed.connect ((c, a, b) => on_closed (c));
          connection.start_message_processing ();

          connection.weak_ref ((o) =>
            {
              var c = (SocketConnection) ((DBusConnection) o).stream;

              try { debug ("DBus disposed (%s)", c.get_remote_address ().to_string ()); }
              catch { debug ("DBus disposed"); }
            });

          return yield register_connection (connection, true, cancellable);
        }

      void prepare_connection (GLib.DBusConnection connection, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var peer = (KademliaDBus.Peer) null;
          var iter = HashTableIter<string, KademliaDBus.Peer> (peers);

          var public_addresses = new (unowned string) [this.public_addresses.length ()];
          var peers = new (unowned string) [this.peers.length];

          int i;
          i = 0; foreach (unowned var item in this.public_addresses) public_addresses [i++] = item;
          i = 0; foreach (unowned var item in this.peers.get_keys ()) peers [i++] = item;

          var node = new NodeSkeleton (public_addresses, peers);

          while (iter.next (null, out peer))
           
            peer.register_on_connection (connection, Node.BASE_PATH);

          lock (nodes) nodes.insert (connection, connection.register_object<Node> (Node.BASE_PATH, node));
        }

      async bool register_connection (GLib.DBusConnection connection, bool incomming, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var object_path = Node.BASE_PATH;
          var node_proxy = yield connection.get_proxy<Node> (null, object_path, 0, cancellable);

          yield node_proxy.Ping ();

          int i = 0;
          var roles = node_proxy.Roles;
          var keys = new Key [roles.length];
          var pubs = new SList<string> ();

          foreach (unowned var address in node_proxy.PublicAddresses)
            {
              pubs.prepend (address);
            }

          foreach (unowned var role in roles)
            {
              var node_role = yield connection.get_proxy<NodeRole> (null, @"$object_path/$role", 0, cancellable);
              var node_key = new Key.verbatim (node_role.Id);

              keys [i++] = (owned) node_key;
            }

          i = 0;

          lock (cached) foreach (unowned var role in roles)
            {
              var list = pubs.copy_deep ((s) => s);

              cached_connections.insert (keys [i].copy (), connection);
              cached_public_addresses.insert ((owned) keys [i], (owned) list);
              ++i;
            }
          return true;
        }
    }
}
