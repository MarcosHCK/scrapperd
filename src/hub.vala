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
  public abstract class Hub : GLib.Object
    {
      public GenericSet<Address?> addresses { get; construct; }
      public GLib.HashTable<Key, GenericSet<Address?>> contacts { get; construct; }
      public GLib.HashTable<Key, Local?> locals { get; construct; }
      public GLib.HashTable<Key, Role> roles { get; construct; }

      public struct Local
        {
          public string role;
          public PeerImpl peer;

          public Local (string role, PeerImpl peer)
            {
              this.role = role;
              this.peer = peer;
            }
        }

      [CCode (scope = "notified")]

      public delegate void ForeachLocalFunc (Key id, string role, PeerImpl peer) throws GLib.Error;

      construct
        {
          addresses = new GenericSet<Address?> (Address.hash, Address.equal);
          contacts = new HashTable<Key, GenericSet<Address?>> (Key.hash, Key.equal);
          locals = new HashTable<Key, Local?> (Key.hash, Key.equal);
          roles = new HashTable<Key, Role> (Key.hash, Key.equal);
        }

      public virtual void add_contact_addresses (Key id, Address[] addresses)
        {
          lock (contacts)
            {
              unowned GLib.EqualFunc<Address?> equal_func = Address.equal;
              unowned GLib.HashFunc<Address?> hash_func = Address.hash;
              GenericSet<Address?> older;
              Key oldkey;

              if (contacts.steal_extended (id, out oldkey, out older) == false)
                {
                  oldkey = id.copy ();
                  older = new GenericSet<Address?> (hash_func, equal_func);
                }

              foreach (unowned var address in addresses)

                older.add (address);

              contacts.insert ((owned) oldkey, (owned) older);
            }
        }

      protected void add_contact_role (Key id, Role role)
        {
          lock (contacts) lock (roles) roles.insert (id.copy (), role);
        }

      public void add_local_address (string address, uint16 port)
        {
          lock (addresses) addresses.add (Address (address, port));
        }

      public void add_local_peer (string role, PeerImpl peer) requires (peer.hub == null)
        {
          lock (locals) locals.insert (peer.id.copy (), Local (role, peer));
          peer.hub = this;

          debug ("exposing peer %s:%s", role, peer.id.to_string ());
        }

      public async ValuePeer create_proxy (string role, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var tolist = new GLib.SList<Key> ();
          var proxy = new PeerImplProxy (this, role);

          lock (roles)
            {
              unowned Key to;
              unowned Role? rol;

              var iter = HashTableIter<Key, Role> (roles);

              while (iter.next (out to, out rol)) if (role == rol.role)

                tolist.prepend (to.copy ());
            }

          foreach (unowned var to in tolist) yield proxy.join (to, cancellable);
          return proxy;
        }

      public void drop_all (Key id)
        {
          lock (contacts) lock (roles)
            {
              contacts.remove_all ();
              roles.remove_all ();
            }
        }

      public void drop_contact (Key id)
        {
          lock (contacts) lock (roles)
            {
              contacts.remove (id);
              roles.remove (id);
            }
        }

      public void drop_role (Key id)
        {
          lock (roles) roles.remove (id);
        }

      protected void drop_contact_address (Key id, Address? address)
        {
          GenericSet<Address?> addresses;

          lock (contacts) if ((addresses = contacts.lookup (id)) != null)
            {
              addresses.remove (address);
              if (addresses.length == 0) contacts.remove (id);
            }
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

      public async bool join (Key id, string role, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var any = 0;

          lock (locals) foreach (unowned var local in locals.get_values ()) if (local.role == role)
            {
              any += (yield local.peer.join (id, cancellable)) ? 1 : 0;
            }

          return any > 0;
        }

      public Address[] list_local_addresses ()
        {
          lock (addresses)
            {
              var addr = (Address?) null;
              var ar = (Address[]) new Address [addresses.length];
              var iter = (GenericSetIter<Address?>) addresses.iterator ();
              int i = 0;

              while ((addr = iter.next_value ()) != null)

                ar [i++] = addr;

              return (owned) ar;
            }
        }

      public KeyRef[] list_local_ids ()
        {
          lock (locals)
            {
              var ar = new Array<KeyRef> ();
              var iter = HashTableIter<Key, Local?> (locals);
              unowned Local? local;

              while (iter.next (null, out local))

                ar.append_val (KeyRef (local.peer.id.bytes));

              return ar.steal ();
            }
        }

      public Address[] list_remote_addresses (Key key)
        {
          GenericSet<Address?> addresses;

          lock (contacts) if ((addresses = contacts.lookup (key)) != null)
            {
              var addr = (Address?) null;
              var ar = (Address[]) new Address [addresses.length];
              var iter = (GenericSetIter<Address?>) addresses.iterator ();
              int i = 0;

              while ((addr = iter.next_value ()) != null)

                ar [i++] = addr;

              return (owned) ar;
            }

          return new Address [0];
        }

      public async Role lookup_role (Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          Role? role;
          Local? local;

          for (unowned var tries = 0; tries < 3; ++tries)
            {
              lock (roles) role = roles.lookup (id);

              if (unlikely (role != null))

                return role;
              else
                {
                  lock (locals) local = locals.lookup (id);

                  if (likely (local != null))
                    {
                      add_contact_role (id, new RoleSkeleton (this, local.role, local.peer));
                    }
                  else while (false == yield reconnect (id, cancellable))
                    {
                      GLib.Thread.yield ();
                    }
                }
            }

          throw new PeerError.UNREACHABLE ("can not reach node %s", id.to_string ());
        }

      public abstract async bool reconnect (Key id, GLib.Cancellable? cancellable = null) throws GLib.Error;

      public void remove_local_peer (Key id)
        {
          Local? local = null;

          lock (locals) locals.steal_extended (id, null, out local);
          if (local != null) local.peer.hub = null;
        }

      public Address? pick_contact_address (Key id)
        {
          lock (contacts)
            {
              var addresses = contacts.lookup (id);
              var iter = addresses == null ? (GenericSetIter<Address?>?) null : addresses.iterator ();
              return iter == null ? null : iter.next_value ();
            }
        }

      public Role? pick_contact_role (Key id)
        {
          lock (roles) return roles.lookup (id);
        }
    }
}
