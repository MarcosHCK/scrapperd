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
  public class NodeSkeleton : GLib.Object, Kademlia.DBus.Node
    {
      private WeakRef _hub;
      public Hub hub { owned get { return (Hub) _hub.get (); } set { _hub.set (value); } }

      public NodeSkeleton (Hub hub)
        {
          this._hub.set (hub);
        }

      public async Address[] list_addresses (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          return hub.list_local_addresses ();
        }

      public async KeyRef[] list_ids (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          return hub.list_local_ids ();
        }
    }

  public class RoleSkeleton : GLib.Object, Kademlia.DBus.Role
    {
      private WeakRef _hub;
      public Hub hub { owned get { return (Hub) _hub.get (); } set { _hub.set (value); } }
      public string name { get; construct; }
      public ValuePeer value_peer { get; construct; }

      public KeyRef id { owned get { return KeyRef (value_peer.id.bytes); } }
      public string role { owned get { return _name; } }

      public RoleSkeleton (Hub hub, string role, ValuePeer value_peer)
        {
          Object (hub : hub, name : role, value_peer : value_peer);
        }

      public async PeerRef[] find_node (PeerRef from_, KeyRef key, GLib.Cancellable? cancellable) throws GLib.Error
        {
          var from = from_.know (hub);
          var id = new Key.verbatim (key.value);
          var re = yield value_peer.find_peer_complete (from, id, cancellable);
          var ar = new PeerRef [re.length];

          for (int i = 0; i < ar.length; ++i) ar [i] = PeerRef (re [i].bytes, hub.list_remote_addresses (re [i]));
          return (owned) ar;
        }

      public async ValueRef find_value (PeerRef from_, KeyRef key, GLib.Cancellable? cancellable) throws GLib.Error
        {
          var from = (Key?) from_.know (hub);
          var id = (Key) new Key.verbatim (key.value);
          var value = (Value) yield value_peer.find_value_complete (from, id, cancellable);

          if (value.is_inmediate)

            return ValueRef.inmediate (value.value);
          else
            {
              var ks = (Key[]) value.steal_keys ();
              var ar = new PeerRef [ks.length];

              for (int i = 0; i < ks.length; ++i) ar [i] = PeerRef (ks [i].bytes, hub.list_remote_addresses (ks [i]));
              return ValueRef.delegated ((owned) ar);
            }
        }

      public async bool store (PeerRef from_, KeyRef key, GLib.Variant value, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var from = (Key?) from_.know (hub);
          var id = (Key) new Key.verbatim (key.value);
          var go = (bool) yield value_peer.store_value_complete (from, id, GValr.net2nat (value), cancellable);
          return go;
        }

      public async bool ping (PeerRef from_, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var from = (Key?) from_.know (hub);
          return yield value_peer.ping_peer_complete (from, cancellable);
        }
    }
}
