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

[CCode (cprefix = "ScrapperdStorage", lower_case_cprefix = "scrapperd_storage_")]

namespace ScrapperD.Storage
{
  struct Entry
    {
      public int64 in_time;
      public GLib.Value value;

      public Entry (owned GLib.Value value)
        {
          this.in_time = GLib.get_monotonic_time ();
          this.value = value;
        }
    }

  public class Store : GLib.Object, ValueStore
    {
      public const int64 VALUE_TIMESPAN = 3 * Buckets.USEC_PER_SEC;
      private GLib.HashTable<Key, Entry?> values;

      construct
        {
          values = new HashTable<Key, Entry?> (Key.hash, Key.equal);
        }

      public override async Kademlia.Key[] enumerate_staled_values (GLib.Cancellable? cancellable) throws GLib.Error
        {
          unowned Key key;
          unowned Entry? entry;
          var array = new GenericArray<Key> ();
          var iter = HashTableIter<Key, Entry?> (values);
          var now = (int64) GLib.get_monotonic_time ();

          while (iter.next (out key, out entry))
            {
              if (now - entry.in_time > VALUE_TIMESPAN)

                array.add (key.copy ());
            }
          return array.steal ();
        }

      public async bool insert_value (Kademlia.Key id, GLib.Value? value, GLib.Cancellable? cancellable) throws GLib.Error
        {
          debug ("insert value %s", id.to_string ());

          lock (values)

            if (value == null)

              values.remove (id);
            else
              {
                var copy = GLib.Value (value.type ());

                value.copy (ref copy);
                values.insert (id.copy (), Entry ((owned) copy));
              }
          return true;
        }

      public async GLib.Value? lookup_value (Kademlia.Key id, GLib.Cancellable? cancellable) throws GLib.Error
        {
          debug ("lookup value %s", id.to_string ());
          unowned GLib.Value? value;

          lock (values)

            if ((value = values.lookup (id).value) == null)

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
