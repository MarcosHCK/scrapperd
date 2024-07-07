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

[CCode (cprefix = "KDBus", lower_case_cprefix = "k_dbus_")]

namespace Kademlia.DBus
{
  public class NetworkHub : Hub
    {
      public const uint16 DEFAULT_PORT = 33334;

      private GLib.ThreadPool<GLib.SocketConnection> incomming_pool;
      private GLib.SocketService socket_service;

      struct RegIds
        {
          public uint node_regid;
          public uint[] role_regids;

          public RegIds (uint node_regid, owned uint[] role_regids)
            {
              this.node_regid = node_regid;
              this.role_regids = (owned) role_regids;
            }
        }

      construct
        {
          int max_threads;

          try
            {
              max_threads = (int) GLib.get_num_processors ();
              incomming_pool = new GLib.ThreadPool<GLib.SocketConnection>.with_owned_data (on_incoming_pooled, max_threads, false);
              socket_service = new GLib.SocketService ();

              socket_service.stop ();
              socket_service.incoming.connect (on_incoming);
            }
          catch (GLib.Error e)
            {
              error (@"$(e.domain): $(e.code): $(e.message)");
            }
        }

      public new async void add_local_address (string host_and_port, uint16 default_port, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var network_address = GLib.NetworkAddress.parse (host_and_port, default_port);
          var address_enumerator = network_address.enumerate ();
          var effective_address = (GLib.SocketAddress?) null;
          var address = (GLib.SocketAddress?) null;

          while ((address = yield address_enumerator.next_async (cancellable)) != null)
            {
              var protocol = GLib.SocketProtocol.TCP;
              var type = GLib.SocketType.STREAM;

              socket_service.add_address (address, type, protocol, address, out effective_address);

              var inet_address = ((GLib.InetSocketAddress) effective_address).address;
              var inet_port = ((GLib.InetSocketAddress) effective_address).port;
              base.add_local_address (inet_address.to_string (), (uint16) inet_port);
            }
        }

      private async Node? connect_to (string host_and_port, uint16 default_port, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var flags1 = GLib.DBusConnectionFlags.AUTHENTICATION_CLIENT;
          var flags2 = GLib.DBusConnectionFlags.DELAY_MESSAGE_PROCESSING;
          var flags = flags1 | flags2;
          var stream = (IOStream) yield (new SocketClient ()).connect_to_host_async (host_and_port, default_port, cancellable);
          var dbus = yield new GLib.DBusConnection (stream, null, flags, null, cancellable);

          yield prepare_connection (dbus, cancellable);

          dbus.exit_on_close = false;
          dbus.start_message_processing ();

          return yield register_connection (dbus, cancellable);
        }

      public async bool join_at (string host_and_port, uint16 default_port, string? role, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var any = 0;
          var node = yield connect_to (host_and_port, default_port, cancellable);

          foreach (unowned var keyref in yield node.list_ids (cancellable))
            {
              var id = (Key) new Key.verbatim (keyref.value);
              var rol = (Role) yield lookup_role (id, cancellable);

              if (role == null || role == rol.role)

                any += (yield join (id, rol.role, cancellable)) ? 1 : 0;
            }

          return any > 0;
        }

      static void on_closed (GLib.DBusConnection dbus, RegIds? regids)
        {
          foreach (unowned var regid in regids.role_regids)

            dbus.unregister_object (regid);
            dbus.unregister_object (regids.node_regid);
        }

      private bool on_incoming (GLib.SocketConnection socket_connection)
        {
          try { incomming_pool.add (socket_connection); } catch (GLib.Error e)
            {
              critical (@"$(e.domain): $(e.code): $(e.message)");
            }
          return true;
        }

      private async Node? on_incoming_async (GLib.SocketConnection socket_connection, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var flags1 = GLib.DBusConnectionFlags.AUTHENTICATION_ALLOW_ANONYMOUS;
          var flags2 = GLib.DBusConnectionFlags.AUTHENTICATION_SERVER;
          var flags3 = GLib.DBusConnectionFlags.DELAY_MESSAGE_PROCESSING;
          var flags = flags1 | flags2 | flags3;
          var guid = GLib.DBus.generate_guid ();
          var dbus = yield new GLib.DBusConnection (socket_connection, guid, flags, null, cancellable);

          yield prepare_connection (dbus, cancellable);

          dbus.exit_on_close = false;
          dbus.start_message_processing ();

          return yield register_connection (dbus, cancellable);
        }

      private void on_incoming_pooled (owned GLib.SocketConnection socket_connection)
        {
          on_incoming_async.begin (socket_connection, null, (o, res) =>
            {

              try { ((NetworkHub) o).on_incoming_async.end (res); } catch (GLib.Error e)
                {
                  critical (@"$(e.domain): $(e.code): $(e.message)");
                }
            });
        }

      private async bool prepare_connection (GLib.DBusConnection dbus, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var node = new NodeSkeleton (this);
          var node_regid = dbus.register_object<Node> (Node.BASE_PATH, node);
          var role_regids = new Array<uint> ();

          foreach_local ((id, role, value_peer) =>
            {
              var rol = new RoleSkeleton (this, role, value_peer);
              var regid = dbus.register_object<Role> (@"$(Node.BASE_PATH)/$id", rol);
              role_regids.append_val (regid);
            });

          var regids = RegIds (node_regid, role_regids.steal ());

          dbus.on_closed.connect ((c, a, b) => on_closed (c, regids));
          return true;
        }

      public void start () { socket_service.start (); }

      public void stop () { socket_service.stop (); }

      protected override async bool reconnect (Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var address = pick_contact_address (id);

          if (unlikely (address == null))
            {
              var id_s = id.to_string ();
              debug ("not route to node %s", id_s);
              throw new PeerError.UNREACHABLE ("can not reach node '%s'", id_s);
            }
          else try
            {
              return null != yield connect_to (address.address, address.port, cancellable);
            }
          catch (GLib.Error e)
            {
              drop_contact_address (id, address);
            }

          return false;
        }

      private async Node? register_connection (GLib.DBusConnection dbus, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          unowned var object_path = Node.BASE_PATH;

          var node = yield dbus.get_proxy<Node> (null, object_path, 0, cancellable);
          var addresses = yield node.list_addresses (cancellable);
          var keyrefs = yield node.list_ids (cancellable);

          foreach (unowned var keyref in keyrefs)
            {
              var id = new Key.verbatim (keyref.value);
              var role = yield dbus.get_proxy<Role> (null, @"$object_path/$id", 0, cancellable);

              add_contact_addresses (id, addresses);
              add_contact_role (id, role);
            }

          return (owned) node;
        }
    }
}
