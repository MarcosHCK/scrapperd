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
  [DBus (name = "org.hck.kademlia.ValueNode")]

  public interface ValueNode : GLib.Object
    {

      public struct PeerRef
        {
          string[]? addresses;
          uint8[]? id;
          bool knowable;

          public PeerRef (owned uint8[] id, owned string[] addresses)
            {
              this.addresses = (owned) addresses;
              this.id = (owned) id;
              this.knowable = true;
            }

          public PeerRef.anonymous (owned uint8[] id)
            {
              this.id = (owned) id;
              this.knowable = false;
            }

          internal Key? know (Hub hub, Peer peer)
            {
              Key? key = null;

              if (knowable)
                {
                  key = new Key.verbatim (id);
                  hub.known_peer (key, addresses);
                }

              return (owned) key;
            }
        }

      public struct ValueRef
        {
          bool found;
          PeerRef[]? peers;
          uint8[]? value;

          public ValueRef.delegated (owned PeerRef[] peers)
            {
              this.found = false;
              this.peers = (owned) peers;
            }

          public ValueRef.inmediate (owned GLib.Value? value) requires (value.type () == typeof (GLib.Bytes))
            {
              this.found = true;
              this.value = ((GLib.Bytes) value.get_boxed ()).get_data ().copy ();
            }
        }

      [DBus (name = "FindNode")] public abstract async PeerRef[] find_node (PeerRef from, uint8[] key, GLib.Cancellable? cancellable = null) throws GLib.Error;
      [DBus (name = "FindValue")] public abstract async ValueRef find_value (PeerRef from, uint8[] key, GLib.Cancellable? cancellable = null) throws GLib.Error;
      [DBus (name = "Store")] public abstract async bool store (PeerRef from, uint8[] key, uint8[] value, GLib.Cancellable? cancellable = null) throws GLib.Error;
      [DBus (name = "Ping")] public abstract async bool ping (PeerRef from, GLib.Cancellable? cancellable = null) throws GLib.Error;
    }
}
