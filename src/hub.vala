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
  public class Hub : GLib.Object
    {
      public GenericSet<Address?> addresses { get; construct; }
      public GLib.HashTable<Key, GenericSet<Address?>> contacts { get; construct; }
      public GLib.HashTable<Key, Node> nodes { get; construct; }
      public GLib.HashTable<Key, Role> roles { get; construct; }

      construct
        {
          addresses = new GenericSet<Address?> (Address.hash, Address.equal);
          contacts = new HashTable<Key, GenericSet<Address?>> (Key.hash, Key.equal);
          nodes = new HashTable<Key, Node> (Key.hash, Key.equal);
          roles = new HashTable<Key, Role> (Key.hash, Key.equal);
        }

      public virtual void add_contact (Key id, Address[] addresses)
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

      protected void add_contact_complete (Key id, Node node, Role role)
        {
          lock (contacts)
            {
              lock (nodes) nodes.insert (id.copy (), node);
              lock (roles) roles.insert (id.copy (), role);
            }
        }

      public void drop_all (Key id)
        {
          lock (contacts) lock (nodes) lock (roles)
            {
              contacts.remove_all ();
              nodes.remove_all ();
              roles.remove_all ();
            }
        }

      public void drop_contact (Key id)
        {
          lock (contacts) lock (nodes) lock (roles)
            {
              contacts.remove (id);
              nodes.remove (id);
              roles.remove (id);
            }
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
          lock (roles)
            {
              var ar = new Array<KeyRef> ();
              var iter = HashTableIter<Key, Role> (roles);
              var role = (Role?) null;

              while (iter.next (null, out role)) if (role is RoleSkeleton)

                ar.append_val (KeyRef (role.id.value));

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

      public async Node lookup_node (Key key, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          Node? node;
          lock (nodes) node = nodes.lookup (key);

          if (unlikely (node != null))

            return node;
          else
            throw new PeerError.UNREACHABLE ("can not reach node %s", key.to_string ());
        }

      public async Role lookup_role (Key key, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          Role? role;
          lock (roles) role = roles.lookup (key);

          if (unlikely (role != null))

            return role;
          else
            throw new PeerError.UNREACHABLE ("can not reach node %s", key.to_string ());
        }
    }
}
