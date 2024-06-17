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
  public class ValueNodeSkeleton : GLib.Object, ValueNode
    {
      public Hub hub { get; construct; }
      public ValuePeer peer { get; construct; }

      public ValueNodeSkeleton (Hub hub, ValuePeer peer)
        {
          Object (hub : hub, peer : peer);
        }

      void know_peer (PeerRef? @ref)
        {
          var id = new Key.verbatim (@ref.id);

          hub.known_peer (id, @ref.addresses);
          peer.add_contact (id);
        }

      public async PeerRef[] find_node (PeerRef from, uint8[] key, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          know_peer (from);
          var ni = (SList<Key>) peer.nearest (new Key.verbatim (key));
          var ar = (PeerRef[]) new PeerRef [ni.length ()];
          int i = 0;

          foreach (unowned var n in ni) ar [i++] = PeerRef (n.bytes, hub.addresses_for_peer (n));
          return (owned) ar;
        }

      public async ValueRef find_value (PeerRef from, uint8[] key, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var id = new Key.verbatim (key);
          var val = (GLib.Value?) null;

          if ((val = yield peer.lookup (id, cancellable)) != null)
            {
              know_peer (from);
              return ValueRef.inmediate (val);
            }
          else
            {
              var ar = (PeerRef[]) yield find_node (from, key, cancellable);
              return ValueRef.delegated ((owned) ar);
            }
        }

      public async bool store (PeerRef from, uint8[] key, uint8[] value, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          know_peer (from);
          yield peer.insert (new Key.verbatim (key), new GLib.Bytes (value));
          return false;
        }

      public async bool ping (PeerRef from, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          know_peer (from);
          return true;
        }
    }
}
