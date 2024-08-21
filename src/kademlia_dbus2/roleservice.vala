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

  public abstract class RoleService : GLib.Object, LocalRegistry, RoleProvider, RoleRegistry
    {
      public AddressService address_service { get; construct; }
      private GLib.HashTable<Key, Local?> locals;
      private GLib.HashTable<Key, Role> roles;

      construct
        {
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

      public bool has_local (Key id)
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

      public async Role lookup (Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
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

      public Role? pick (Key id)
        {
          lock (roles) return roles.lookup (id);
        }

      public abstract async Node? reach (Address? address, GLib.Cancellable? cancellable = null) throws GLib.Error;

      protected virtual async bool reconnect (Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var address = address_service.pick (id);
          var prevrole = pick (id)?.role;

          if (unlikely (address == null))
            {
              var id_s = id.to_string ();
              debug ("not route to node %s", id_s);
              throw new PeerError.UNREACHABLE ("can not reach node '%s'", id_s);
            }
          else try
            {
              if (unlikely (null == yield reach (address, cancellable)))
                {
                  if (unlikely (prevrole == null))
                    {
                      throw new PeerError.UNREACHABLE ("peer has no roles %s", id.to_string ());
                    }
                  else if (prevrole != pick (id)?.role)
                    {
                      debug ("peer registered as %s, vanished", id.to_string ());
                      throw new NetworkError.RESETTED ("peer vanished %s:%s", prevrole, id.to_string ());
                    }
                }
              else
                {
                  var role = (Role?) pick (id);
                  var newid = new Key.verbatim (role.id.value);

                  if (unlikely (Key.equal (id, newid) == false || (prevrole != null && prevrole != role.role)))
                    {

                      if (Key.equal (id, newid) == false)

                        debug ("peer registered as %s, id changed to %s", id.to_string (), newid.to_string ());

                      else if (prevrole != null && prevrole != role.role)

                        debug ("peer registered role was %s, changed to %s", prevrole, role.role);

                      throw new NetworkError.RESETTED ("peer role was resetted (maybe address collision?)");
                    }

                  return true;
                }
            }
          catch (GLib.Error e)
            {
              if (e.domain == GLib.IOError.quark ())

                switch (e.code)
                  {
                    case GLib.IOError.CONNECTION_REFUSED:
                    case GLib.IOError.HOST_UNREACHABLE:
                    case GLib.IOError.NETWORK_UNREACHABLE:

                      address_service.drop (id, new Address [] { address });
                      break;

                    default: throw (owned) e;
                  }

              else throw (owned) e;
            }

          return false;
        }
    }
}
