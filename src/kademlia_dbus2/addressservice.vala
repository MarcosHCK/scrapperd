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
  public class AddressService : GLib.Object, AddressProvider, AddressRegistry
    {
      private GenericSet<Address?> addresses;
      private GLib.HashTable<Key, GenericSet<Address?>> contacts;

      construct
        {
          addresses = new GenericSet<Address?> (Address.hash, Address.equal);
          contacts = new HashTable<Key, GenericSet<Address?>> (Key.hash, Key.equal);
        }

      public void AddressRegistry.add (Key? id, Address[] addresses_)
        {
          if (id == null) lock (addresses)
            {
              foreach (unowned var addr in addresses_) addresses.add (addr);
            }
          else lock (contacts)
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

      public void AddressRegistry.drop (Key? id, Address[] addresses_)
        {
          if (id == null) lock (addresses)
            {
              foreach (unowned var addr in addresses_) addresses.remove (addr);
            }
          else lock (contacts)
            {
              GenericSet<Address?> addresses;

              if ((addresses = contacts.lookup (id)) != null)
                {
                  foreach (unowned var addr in addresses_) addresses.remove (addr);
                  if (addresses.length == 0) contacts.remove (id);
                }
            }
        }

      public bool has_contact (Key id)
        {
          lock (contacts) return contacts.contains (id);
        }

      public Address[] AddressProvider.locals ()
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

      public Address[] AddressProvider.lookup (Key id)
        {
          GenericSet<Address?> addresses;

          lock (contacts) if ((addresses = contacts.lookup (id)) != null)
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

      public Address? pick (Key id)
        {
          lock (contacts)
            {
              var addresses = contacts.lookup (id);
              var iter = addresses == null ? (GenericSetIter<Address?>?) null : addresses.iterator ();
              return iter == null ? null : iter.next_value ();
            }
        }
    }
}
