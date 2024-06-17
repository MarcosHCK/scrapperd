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
  [DBus (name = "org.hck.ScrapperD.Node")]

  public interface StorageNode : GLib.Object
    {
      public const string ROLE = "storage";

      public struct Neighbor
        {
          public uint8[] id;

          public Neighbor (owned uint8[] id)
            {
              this.id = (owned) id;
            }
        }

      public struct Value
        {
          public bool found;
          public Neighbor[]? neighbors;
          public uint8[]? value;

          public Value.delegated (owned GLib.SList<Key> neighbors)
            {
              var ar = new Neighbor [neighbors.length ()];
              var i = 0;

              foreach (unowned var item in neighbors) ar [i++] = Neighbor (item.bytes);
              this.neighbors = (owned) ar;
              this.found = false;
            }

          public Value.inmediate (owned GLib.Value? value) requires (value.type () == typeof (GLib.Bytes))
            {
              this.found = true;
              this.value = ((GLib.Bytes) value.get_boxed ()).get_data ().copy ();
            }
        }

      [DBus (name = "FindNode")] public abstract async Neighbor[] find_node (uint8[] key, GLib.Cancellable? cancellable = null) throws GLib.Error;
      [DBus (name = "FindValue")] public abstract async Value find_value (uint8[] key, GLib.Cancellable? cancellable = null) throws GLib.Error;
      [DBus (name = "Store")] public abstract async bool store (uint8[] key, uint8[] value, GLib.Cancellable? cancellable = null) throws GLib.Error;
      [DBus (name = "Ping")] public abstract async bool ping (GLib.Cancellable? cancellable = null) throws GLib.Error;
    }
}
