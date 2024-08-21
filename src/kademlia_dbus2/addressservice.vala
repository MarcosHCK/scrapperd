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
      private GenericSet<Address?> locals;
      private GLib.HashTable<Key, GenericSet<Address?>> roles;

      construct
        {
          locals = new GenericSet<Address?> (Address.hash, Address.equal);
          roles = new HashTable<Key, GenericSet<Address?>> (Key.hash, Key.equal);
        }

      public void AddressRegistry.add (Key? id, Address[] addresses)
        {
          if (id == null) lock (locals)
            {
              foreach (unowned var addr in addresses) locals.add (addr);
            }
          else lock (roles)
            {
              unowned GLib.EqualFunc<Address?> equal_func = Address.equal;
              unowned GLib.HashFunc<Address?> hash_func = Address.hash;
              GenericSet<Address?> older;
              Key oldkey;

              if (roles.steal_extended (id, out oldkey, out older) == false)
                {
                  oldkey = id.copy ();
                  older = new GenericSet<Address?> (hash_func, equal_func);
                }

              foreach (unowned var address in addresses)

                older.add (address);

              roles.insert ((owned) oldkey, (owned) older);
            }
        }

      public void AddressRegistry.drop (Key? id, Address[] addresses)
        {
          if (id == null)

            lock (locals)

              foreach (unowned var addr in addresses) locals.remove (addr);

          else

            lock (roles)
              {
                GenericSet<Address?> old;

                if ((old = roles.lookup (id)) != null)
                  {
                    foreach (unowned var addr in addresses) old.remove (addr);
                    if (old.length == 0) roles.remove (id);
                  }
              }
        }

      public bool has (Key id)
        {
          lock (roles) return roles.contains (id);
        }

      public Address[] AddressProvider.locals ()
        {
          lock (locals)
            {
              var addr = (Address?) null;
              var ar = (Address[]) new Address [locals.length];
              var iter = (GenericSetIter<Address?>) locals.iterator ();

              for (int i = 0; (addr = iter.next_value ()) != null; ++i) ar [i] = addr;
              return (owned) ar;
            }
        }

      public Address[] AddressProvider.lookup (Key id)
        {
          GenericSet<Address?> addresses;

          lock (roles)

            if ((addresses = roles.lookup (id)) != null)
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
          lock (roles)
            {
              var addresses = roles.lookup (id);
              var iter = addresses == null ? (GenericSetIter<Address?>?) null : addresses.iterator ();
              return iter == null ? null : iter.next_value ();
            }
        }
    }
}
