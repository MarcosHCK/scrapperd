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
          public string name;
          public uint8[] id;

          public Neighbor (string name, owned uint8[] id) { this.name = name; this.id = (owned) id; }
        }

      public struct Value
        {
          public Neighbor[]? neighbors;
          public uint8[]? value;

          public Value.delegated (owned Neighbor[] neighbors) { this.neighbors = (owned) neighbors; }
          public Value.exact (owned uint8[] value) { this.value = (owned) value; }
        }

      public abstract uint8[] Id { owned get; }
      [DBus (name = "FindNode")] public abstract async Neighbor[] find_node (uint8[] key) throws GLib.Error;
      [DBus (name = "FindValue")] public abstract async Value find_value (uint8[] key) throws GLib.Error;
      [DBus (name = "Store")] public abstract async void store (uint8[] key, uint8[] value) throws GLib.Error;
      [DBus (name = "Ping")] public abstract async bool ping () throws GLib.Error;
    }

  public class StorageImpl : GLib.Object, Storage
    {
      public HashTable<Kademlia.Key, string> names { get; construct; }
      public HashTable<Kademlia.Key, GLib.Bytes> rows { get; construct; }
      public Kademlia.Node node { get; construct; }
      public uint8[] Id { owned get { return node.id.get_bytes (); } }

      public StorageImpl (Kademlia.Node node)
        {
          Object (node : node);
        }

      construct
        {
          node.find_node.connect ((peer, key) =>
            {
              try { return on_node_find_node (peer, key); } catch (GLib.Error e)
                {
                  critical (@"$(e.domain): $(e.code): $(e.message)");
                  return null;
                }
            });

          node.find_value.connect ((peer, key) =>
            {
              try { return on_node_find_value (peer, key); } catch (GLib.Error e)
                {
                  critical (@"$(e.domain): $(e.code): $(e.message)");
                  return null;
                }
            });

          node.store.connect ((peer, key, value) =>
            {
              try { return on_node_store (peer, key, value); } catch (GLib.Error e)
                {
                  critical (@"$(e.domain): $(e.code): $(e.message)");
                  return false;
                }
            });

          names = new HashTable<Kademlia.Key, string> (Kademlia.Key.hash, Kademlia.Key.equal);
          rows = new HashTable<Kademlia.Key, GLib.Bytes> (Kademlia.Key.hash, Kademlia.Key.equal);
          names.insert (Kademlia.Key.copy (node.id), "1");
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
          print ("length: %i\n", (int) list.length ());

          for (unowned var i = 0, link = list; link != null; link = link.next, ++i)

            ar [i] = Neighbor (names.lookup (link.data), link.data.get_bytes ());

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

      public async void store (uint8[] key, uint8[] value) throws GLib.Error
        {
          if (key.length != Kademlia.Key.BITLEN / 8)
            {
              throw new IOError.INVALID_ARGUMENT ("invalid key");
            }

          yield node.insert (Kademlia.Key.tmp (key), new GLib.Bytes (value));
        }

      public async bool ping ()
        {
          return true;
        }

      private Kademlia.Value? on_node_find_node (Kademlia.Key peer, Kademlia.Key key) throws GLib.Error

          requires (!Kademlia.Key.equal (peer, node.id))
        {
          throw new GLib.IOError.FAILED ("unimplemented");
        }

      private Kademlia.Value? on_node_find_value (Kademlia.Key peer, Kademlia.Key key) throws GLib.Error
        {
          GLib.Bytes? bytes;

          if (Kademlia.Key.equal (peer, node.id))

            return (bytes = rows.lookup (key)) == null ? null : new Kademlia.ValueInmediate ((owned) bytes);
          else
            {
              throw new GLib.IOError.FAILED ("unimplemented");
            }
        }

      private bool on_node_store (Kademlia.Key peer, Kademlia.Key key, GLib.Bytes value) throws GLib.Error
        {
          if (Kademlia.Key.equal (peer, node.id))

            rows.insert (Kademlia.Key.copy (key), value);
          else
            {
              throw new GLib.IOError.FAILED ("unimplemented");
            }
          return true;
        }
    }
}
