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

      public async PeerRef[] find_node (PeerRef from, uint8[] key, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          from.know (hub, peer);
          var id = new Key.verbatim (key);
          var re = yield peer.find_peer_complete (id, cancellable);
          var ar = new PeerRef [re.length];

          for (int i = 0; i < re.length; ++i) ar [i] = PeerRef (re [i].bytes, hub.addresses_for_peer (re [i]));
          return (owned) ar;
        }

      public async ValueRef find_value (PeerRef from, uint8[] key, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          from.know (hub, peer);
          var id = new Key.verbatim (key);
          var value = yield peer.find_value_complete (id, cancellable);

          if (value.is_inmediate)

            return ValueRef.inmediate (value.steal_value ());
          else
            {
              var ks = value.steal_keys ();
              var ar = new PeerRef [ks.length];
              for (int i = 0; i < ks.length; ++i) ar [i] = PeerRef (ks [i].bytes, hub.addresses_for_peer (ks [i]));
              return ValueRef.delegated ((owned) ar);
            }
        }

      public async bool store (PeerRef from, uint8[] key, uint8[] value, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          from.know (hub, peer);
          var id = (Key) new Key.verbatim (key);
          var go = (bool) yield peer.store_value_complete (id, new GLib.Bytes (value), cancellable);
          return go;
        }

      public async bool ping (PeerRef from, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          from.know (hub, peer);
          return yield peer.ping_peer_complete (cancellable);
        }
    }
}
