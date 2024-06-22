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
  public class PeerImpl : ValuePeer
    {
      public string role { get; construct; }

      private GLib.WeakRef _hub;
      private GLib.HashTable<void*, NodeIds?> ifaces;
      private Hub hub { owned get { return (Hub) _hub.get (); } }

      struct NodeIds
        {
          public uint role_id;
          public uint value_id;

          public NodeIds (uint role_id, uint value_id)
            {
              this.role_id = role_id;
              this.value_id = value_id;
            }
        }

      construct
        {
          added_contact.connect ((k) => debug ("added contact '%s'", k.to_string ()));
          dropped_contact.connect ((k) => debug ("dropped contact '%s'", k.to_string ()));
          staled_contact.connect ((k) => debug ("staled contact '%s'", k.to_string ()));
          ifaces = new HashTable<void*, NodeIds?> (GLib.direct_hash, GLib.direct_equal);
        }

      public PeerImpl (string role, ValueStore value_store)
        {
          base (value_store, new Key.random ());
          this._role = role;
        }

      protected virtual ValueNode.PeerRef get_self ()
        {
          return ValueNode.PeerRef (id.bytes, hub.get_public_addresses ());
        }

      internal void register_on_connection (GLib.DBusConnection connection, string object_path) throws GLib.Error
        {
          unowned var id1 = connection.register_object<ValueNode> (@"$object_path/$role", new ValueNodeSkeleton (hub, this));
          unowned var id2 = connection.register_object<NodeRole> (@"$object_path/$role", new NodeRoleSkeleton (this));
          lock (ifaces) ifaces.insert (connection, NodeIds (id1, id2));
        }

      internal void register_on_hub (Hub? hub) requires (hub == null || _hub.get () == null)
        {
          _hub.set (hub);
        }

      internal void unregister_on_connection (GLib.DBusConnection connection)
        {
          NodeIds? ids;
          lock (ifaces) ids = ifaces.lookup (connection);
          connection.unregister_object (ids.role_id);
          connection.unregister_object (ids.value_id);
        }

      protected override async Key[] find_peer (Key peer, Key key, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var proxy = yield hub.get_proxy<ValueNode> (peer, role, cancellable);
          var peers = yield proxy.find_node (get_self (), id.bytes, cancellable);
          var keys = new Key [peers.length];

          for (unowned var i = 0; i < keys.length; ++i)
            {
              keys [i] = new Key.verbatim (peers [i].id);
              peers [i].know (hub, this);
            }
          return (owned) keys;
        }

      protected override async Kademlia.Value find_value (Key peer, Key key, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var proxy = yield hub.get_proxy<ValueNode> (peer, role, cancellable);
          var value = yield proxy.find_value (get_self (), key.bytes, cancellable);

          if (value.found)

            return new Kademlia.Value.inmediate (new GLib.Bytes (value.value));
          else
            {
              var keys = new Key [value.peers.length];

              for (unowned var i = 0; i < keys.length; ++i)
                {
                  keys [i] = new Key.verbatim (value.peers [i].id);
                  value.peers [i].know (hub, this);
                }
              return new Kademlia.Value.delegated ((owned) keys);
            }
        }

      protected override async bool store_value (Key peer, Key key, GLib.Value? value = null, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var proxy = yield hub.get_proxy<ValueNode> (peer, role, cancellable);
          var result = yield proxy.store (get_self (), key.bytes, ValueNode.ValueRef.inmediate (value).value, cancellable);
          return result;
        }

      protected override async bool ping_peer (Key peer, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var proxy = yield hub.get_proxy<ValueNode> (peer, role, cancellable);
          var result = yield proxy.ping (get_self (), cancellable);
          return result;
        }
    }
}
