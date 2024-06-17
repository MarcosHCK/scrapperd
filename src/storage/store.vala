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

[CCode (cprefix = "Scrapperd", lower_case_cprefix = "scrapperd_")]

namespace ScrapperD
{
  public class Store : GLib.Object, ValueStore
    {
      private HashTable<Key, GLib.Value?> values;

      public async override bool insert_value (Kademlia.Key id, GLib.Value? value, GLib.Cancellable? cancellable) throws GLib.Error
        {
          if (value == null)

            values.remove (id);
          else
            {
              var copy = GLib.Value (value.type ());

              value.copy (ref copy);
              values.insert (id.copy (), (owned) copy);
            }
          return true;
        }

      public async override GLib.Value? lookup_value (Kademlia.Key id, GLib.Cancellable? cancellable) throws GLib.Error
        {
          unowned GLib.Value? value;

          if ((value = values.lookup (id)) == null)

            return null;
          else
            {
              var copy = GLib.Value (value.type ());
                value.copy (ref copy);
              return (owned) copy;
            }
        }
    }
}
