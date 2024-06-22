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

[CCode (cprefix = "KDBus", lower_case_cprefix = "kdbus_")]

namespace KademliaDBus
{
  public class ValueNodeSkeleton : GLib.Object, ValueNode
    {
      public Hub hub { get; construct; }
      public ValuePeer peer { get; construct; }

      public ValueNodeSkeleton (Hub hub, ValuePeer peer)
        {
          Object (hub : hub, peer : peer);
        }

      static int compare_key (Key a, Key b)
        {
          return Key.equal (a, b) ? 0 : 1;
        }

      public async PeerRef[] find_node (PeerRef from, uint8[] key, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          from.know (hub, peer);
          var ni = (SList<Key>) peer.nearest (new Key.verbatim (key));
          var ar = (PeerRef[]) new PeerRef [ni.length ()];
          int i = 0;

          foreach (unowned var n in ni) ar [i++] = PeerRef (n.bytes, hub.addresses_for_peer (n));
          return (owned) ar;
        }

      public async ValueRef find_value (PeerRef from, uint8[] key, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          from.know (hub, peer);
          var id = new Key.verbatim (key);
          var val = (GLib.Value?) null;

          if ((val = yield peer.value_store.lookup_value (id, cancellable)) != null)
            
            return ValueRef.inmediate ((owned) val);
          else
            {
              var ni = (SList<Key>) peer.nearest (id);

              ni.foreach (e => { if (Key.equal (e, peer.id)) ni.remove (e); });

              var ar = (PeerRef[]) new PeerRef [ni.length ()];
              int i = 0;

              foreach (unowned var n in ni) ar [i++] = PeerRef (n.bytes, hub.addresses_for_peer (n));
              return ValueRef.delegated ((owned) ar);
            }
        }

      public async bool store (PeerRef from, uint8[] key, uint8[] value, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          from.know (hub, peer);
          var id = (Key) new Key.verbatim (key);
          var ni = (SList<Key>) peer.nearest (id);

          if (ni.find_custom (id, compare_key) != null)

            return yield peer.value_store.insert_value (id, new GLib.Bytes (value), cancellable);
          else
            return yield peer.insert (new Key.verbatim (key), new GLib.Bytes (value));
        }

      public async bool ping (PeerRef from, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          from.know (hub, peer);
          return true;
        }
    }
}
