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
  [CCode (scope = "notified")]

  public delegate void ForeachLocalFunc (Key id, string role, PeerImpl peer) throws GLib.Error;

  struct Local
    {
      public string role;
      public PeerImpl peer;

      public Local (string role, PeerImpl peer)
        {
          this.role = role;
          this.peer = peer;
        }
    }

  public errordomain NetworkError
    {
      FAILED,
      RESETTED;
      public extern static GLib.Quark quark ();
    }

  public abstract class RoleService : GLib.Object, LocalProvider, LocalRegistry, RoleProvider, RoleRegistry
    {
      public AddressService address_service { get; construct; }
      private GenericSet<GLib.DBusConnection> connections;
      private GLib.HashTable<Key, Local?> locals;
      private GLib.HashTable<Key, Role> roles;

      construct
        {
          connections = new GenericSet<DBusConnection> (GLib.direct_hash, GLib.direct_equal);
          locals = new HashTable<Key, Local?> (Key.hash, Key.equal);
          roles = new HashTable<Key, Role> (Key.hash, Key.equal);
        }

      protected RoleService (AddressService address_service)
        {
          Object (address_service : address_service);
        }

      public void LocalRegistry.add (string role, PeerImpl peer)
        {
          lock (locals) locals.insert (peer.id.copy (), Local (role, peer));
        }

      public void RoleRegistry.add (Key id, Role role)
        {
          lock (roles) roles.insert (id.copy (), role);
        }

      public async ValuePeer create_proxy (string role, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          Key[] peers;
          PeerImplProxy proxy;
          unowned AddressProvider address_provider = address_service;
          unowned AddressRegistry address_registry = address_service;
          unowned RoleProvider role_provider = this;
          unowned RoleRegistry role_registry = this;

          lock (roles)
            {
              var ar = new Array<Key> ();
              var iter = HashTableIter<Key, Role> (roles);
              unowned Key id;

              while (iter.next (out id, null)) ar.append_val (id.copy ());
              peers = ar.steal ();
            }

          proxy = new PeerImplProxy (address_provider, null, address_registry, role_provider, role_registry);

          foreach (unowned var to in peers) yield proxy.join (to, cancellable);
          return proxy;
        }

      public void LocalRegistry.drop (Key id)
        {
          lock (locals) locals.remove (id);
        }

      public void RoleRegistry.drop (Key id)
        {
          lock (roles) roles.remove (id);
        }

      public void drop_all ()
        {
          lock (connections) foreach (unowned var connection in connections.get_values ()) connection.close.begin ();
          lock (locals) locals.remove_all ();
          lock (roles) roles.remove_all ();
        }

      public void foreach_local (owned ForeachLocalFunc callback) throws GLib.Error
        {
          lock (locals)
            {
              var iter = HashTableIter<Key, Local?> (locals);
              unowned Key? id;
              unowned Local? local;

              while (iter.next (out id, out local)) callback (id, local.role, local.peer);
            }
        }

      public bool LocalProvider.has (Key id)
        {
          lock (locals) return locals.contains (id);
        }

      public async bool join (Key id, string role, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var locals_ = new List<Local?> ();
          int any = 0;

          lock (locals) foreach (unowned var local in locals.get_values ()) locals_.append (local);
          foreach (unowned var local in locals_) if (local.role == role) any += (yield local.peer.join (id, cancellable)) ? 1 : 0;
          return any > 0;
        }

      public Key[] RoleProvider.locals ()
        {
          lock (locals)
            {
              var ar = new Array<Key> ();
              var iter = HashTableIter<Key, Local?> (locals);
              unowned Local? local;

              while (iter.next (null, out local)) ar.append_val (local.peer.id.copy ());
              return ar.steal ();
            }
        }

      public PeerImpl? LocalProvider.lookup (Key id)
        {
          lock (locals) return locals.lookup (id)?.peer;
        }

      public async Role RoleProvider.lookup (Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          Role? role;
          Local? local;

          unowned AddressProvider address_provider = address_service;
          unowned AddressRegistry address_registry = address_service;
          unowned RoleProvider role_provider = this;

          for (unowned var tries = 0; tries < 3; ++tries)
            {
              lock (roles) role = roles.lookup (id);

              if (unlikely (role != null))

                return role;
              else
                {
                  lock (locals) local = locals.lookup (id);

                  if (likely (local == null))

                    while (false == yield reconnect (id, cancellable))

                      GLib.Thread.yield ();
                  else
                    {
                      var rol = new RoleSkeleton (address_provider, address_registry, local.role, role_provider, local.peer);
                      ((RoleRegistry) this).add (id, rol);
                    }
                }
            }

          throw new PeerError.UNREACHABLE ("can not reach node %s", id.to_string ());
        }

      static void on_closed (GLib.DBusConnection dbus, RegIds? regids)
        {
          foreach (unowned var regid in regids.role_regids)

            dbus.unregister_object (regid);
            dbus.unregister_object (regids.node_regid);

          dbus.stream.close_async.begin ();
        }

      public Role? pick (Key id)
        {
          lock (roles) return roles.lookup (id);
        }

      protected async bool prepare_connection (GLib.DBusConnection dbus, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          unowned AddressProvider address_provider = address_service;
          unowned AddressRegistry address_registry = address_service;
          unowned string object_path = Node.BASE_PATH;
          unowned RoleProvider role_provider = this;

          var node = new NodeSkeleton (address_provider, role_provider);
          var node_regid = dbus.register_object<Node> (object_path, node);
          var role_regids = new Array<uint> ();

          foreach_local ((id, role, value_peer) =>
            {
              var rol = new RoleSkeleton (address_provider, address_registry, role, role_provider, value_peer);
              var regid = dbus.register_object<Role> (@"$(Node.BASE_PATH)/$id", rol);
              role_regids.append_val (regid);
            });

          var regids = RegIds (node_regid, role_regids.steal ());

          lock (connections) connections.add (dbus);

          dbus.on_closed.connect ((c, a, b) =>
            {
              lock (connections) connections.remove (c);
              on_closed (c, regids);
            });

          return true;
        }

      public abstract async Node? reach (Address? address, GLib.Cancellable? cancellable = null) throws GLib.Error;

      protected virtual async bool reconnect (Key id_, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var address = address_service.pick (id_);
          var id = id_.copy ();

          if (unlikely (address == null))
            {
              var id_s = id.to_string ();
              debug ("not route to node %s", id_s);
              throw new PeerError.UNREACHABLE ("can not reach node '%s'", id_s);
            }
          else try
            {
              if (unlikely (null == yield reach (address, cancellable)))

                throw new PeerError.UNREACHABLE ("peer could not be reached %s", id.to_string ());
              else if (unlikely (pick (id) == null))

                throw new NetworkError.RESETTED ("peer vanished %s", id.to_string ());
              return true;
            }
          catch (GLib.Error e)
            {
              if (e.domain == GLib.IOError.quark ())

                switch (e.code)
                  {
                    case GLib.IOError.CONNECTION_REFUSED:
                    case GLib.IOError.HOST_UNREACHABLE:
                    case GLib.IOError.NETWORK_UNREACHABLE:

                      debug ("could not reach using %s:%u %s", address.address, (uint) address.port, id.to_string ());
                      address_service.drop (id, new Address [] { address });
                      break;

                    default: throw (owned) e;
                  }

              else throw (owned) e;
            }

          return false;
        }

      protected async Node? register_connection (GLib.DBusConnection dbus, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          unowned AddressRegistry address_registry = address_service;
          unowned RoleRegistry role_registry = this;
          unowned var object_path = Node.BASE_PATH;

          var node = yield dbus.get_proxy<Node> (null, object_path, 0, cancellable);
          var addresses = yield node.list_addresses (cancellable);
          var keyrefs = yield node.list_ids (cancellable);

          foreach (unowned var keyref in keyrefs)
            {
              var id = new Key.verbatim (keyref.value);
              var role = (Role) yield dbus.get_proxy<Role> (null, @"$object_path/$id", 0, cancellable);

              address_registry.add (id, addresses);
              role_registry.add (id, role);
            }

          return keyrefs.length == 0 ? null : (owned) node;
        }
    }
}
