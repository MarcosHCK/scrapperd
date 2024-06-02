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

[CCode (cprefix = "Scrapperd", lower_case_cprefix = "scrapperd_")]

namespace ScrapperD
{
  [DBus (name = "org.hck.ScrapperD.Node.Storage")]

  public interface Storage : GLib.Object
    {
      public struct Neighbor
        {
          public uint8[] id;

          public Neighbor (owned uint8[] id)
            {
              this.id = (owned) id;
            }

          public static Kademlia.Value cast (Neighbor[] neighbors)
            {
              var ar = new (unowned Kademlia.Key?) [neighbors.length];

              for (var i = 0; i < ar.length; ++i) ar [i] = Kademlia.Key.tmp (neighbors [i].id);
              return new Kademlia.ValueDelegated (ar);
            }
        }

      public struct Value
        {
          public Neighbor[]? neighbors;
          public uint8[]? value;

          public Value.delegated (owned Neighbor[] neighbors)
            {
              this.neighbors = (owned) neighbors;
            }

          public Value.exact (owned uint8[] value)
            {
              this.value = (owned) value;
            }

          public static Kademlia.Value cast (Value value)
            {
              if (value.neighbors != null)
                {
                  return Neighbor.cast (value.neighbors);
                }
              else
                {
                  var ay = new GLib.Bytes (value.value);
                  return new Kademlia.ValueInmediate (ay);
                }
            }
        }

      public abstract uint8[] Id { owned get; }
      [DBus (name = "FindNode")] public abstract async Neighbor[] find_node (uint8[] key) throws GLib.Error;
      [DBus (name = "FindValue")] public abstract async Value find_value (uint8[] key) throws GLib.Error;
      [DBus (name = "Store")] public abstract async bool store (uint8[] key, uint8[] value) throws GLib.Error;
      [DBus (name = "Ping")] public abstract async bool ping () throws GLib.Error;
    }

  public class StorageSkeleton : GLib.Object, Storage
    {
      public HashTable<Kademlia.Key, GLib.Bytes> rows { get; construct; }
      public Kademlia.Node node { get; construct; }
      public uint8[] Id { owned get { return node.id.get_bytes (); } }

      public signal Kademlia.Value? on_find_node (Kademlia.Key peer, Kademlia.Key key);
      public signal Kademlia.Value? on_find_value (Kademlia.Key peer, Kademlia.Key key);
      public signal bool on_store (Kademlia.Key peer, Kademlia.Key key, GLib.Bytes value);

      construct
        {

          node.find_node.connect ((peer, key) =>
            {
              assert (!Kademlia.Key.equal (peer, node.id));
              return on_find_node (peer, key);
            });

          node.find_value.connect ((peer, key) =>
            {
              GLib.Bytes? bytes;

              if (Kademlia.Key.equal (peer, node.id))

                return (bytes = rows.lookup (key)) == null ? null : new Kademlia.ValueInmediate ((owned) bytes);
              else
                return on_find_value (peer, key);
            });

          node.store.connect ((peer, key, value) =>
            {
              if (Kademlia.Key.equal (peer, node.id))

                return rows.insert (Kademlia.Key.copy (key), value) || true;
              else
                return on_store (peer, key, value);
            });

          rows = new HashTable<Kademlia.Key, GLib.Bytes> (Kademlia.Key.hash, Kademlia.Key.equal);
        }

      public StorageSkeleton (Kademlia.Node node)
        {
          Object (node : node);
        }

      public async Neighbor[] find_node (uint8[] key) throws GLib.Error
        {
          Neighbor [] ar;
          GLib.SList<Kademlia.Key> list;

          if (key.length != Kademlia.Key.BITLEN / 8)
            {
              throw new IOError.INVALID_ARGUMENT ("invalid key");
            }

          list = node.nearest (Kademlia.Key.tmp (key));
          ar = new Neighbor [list.length ()];

          for (unowned var i = 0, link = list; link != null; link = link.next, ++i)

            ar [i] = Neighbor (link.data.get_bytes ());

          return ar;
        }

      public async Value find_value (uint8[] key) throws GLib.Error
        {
          GLib.Bytes? bytes;

          if (key.length != Kademlia.Key.BITLEN / 8)
            {
              throw new IOError.INVALID_ARGUMENT ("invalid key");
            }

          if ((bytes = yield node.lookup (Kademlia.Key.tmp (key))) != null)

            return Value.exact (bytes.get_data ());
          else
            return Value.delegated (yield find_node (key));
        }

      public async bool store (uint8[] key, uint8[] value) throws GLib.Error
        {
          if (key.length != Kademlia.Key.BITLEN / 8)
            {
              throw new IOError.INVALID_ARGUMENT ("invalid key");
            }

          yield node.insert (Kademlia.Key.tmp (key), new GLib.Bytes (value));
          return true;
        }

      public async bool ping ()
        {
          return true;
        }
    }
}
