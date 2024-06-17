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
  public const string ROLE = "storage";

  public class Peer : ValuePeer
    {
      public Hub hub { get; construct; }

      construct
        {
          added_contact.connect ((k) => debug ("added contact '%s'", k.to_string ()));
          staled_contact.connect ((k) => debug ("staled contact '%s'", k.to_string ()));
        }

      public Peer (Hub hub)
        {
          base (new Store (), new Key.random ());
          this._hub = hub;
        }

      private ValueNode.PeerRef get_self ()
        {
          return ValueNode.PeerRef (id.bytes, hub.get_public_addresses ());
        }

      protected override async Key[] find_peer (Key peer, Key key, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var proxy = yield hub.get_proxy<ValueNode> (peer, ROLE, cancellable);
          var peers = yield proxy.find_node (get_self (), id.bytes, cancellable);
          var keys = new Key [peers.length];

          for (unowned var i = 0; i < keys.length; ++i)
            {
              keys [i] = new Key.verbatim (peers [i].id);
              hub.known_peer (keys [i], peers [i].addresses);
            }
          return (owned) keys;
        }

      protected override async Kademlia.Value find_value (Key peer, Key key, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var proxy = yield hub.get_proxy<ValueNode> (peer, ROLE, cancellable);
          var value = yield proxy.find_value (get_self (), key.bytes, cancellable);

          if (value.found)

            return new Kademlia.Value.inmediate (new GLib.Bytes (value.value));
          else
            {
              var keys = new Key [value.peers.length];

              for (unowned var i = 0; i < keys.length; ++i)
                {
                  keys [i] = new Key.verbatim (value.peers [i].id);
                  hub.known_peer (keys [i], value.peers [i].addresses);
                }
              return new Kademlia.Value.delegated ((owned) keys);
            }
        }

      protected override async bool store_value (Key peer, Key key, GLib.Value? value = null, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var proxy = yield hub.get_proxy<ValueNode> (peer, ROLE, cancellable);
          var result = yield proxy.store (get_self (), key.bytes, ValueNode.ValueRef.inmediate (value).value, cancellable);
          return result;
        }

      protected override async bool ping_peer (Key peer, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var proxy = yield hub.get_proxy<ValueNode> (peer, ROLE, cancellable);
          var result = yield proxy.ping (get_self (), cancellable);
          return result;
        }
    }
}
