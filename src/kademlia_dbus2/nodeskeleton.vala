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
      public AddressProvider address_provider { get; construct; }
      public RoleProvider role_provider { get; construct; }

      public NodeSkeleton (AddressProvider address_provider, RoleProvider role_provider)
        {
          Object (address_provider : address_provider, role_provider : role_provider);
        }

      public async Address[] list_addresses (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var ar = (Address[]) address_provider.locals ();
          var ar2 = new Address [ar.length];
          int i = 0;

          foreach (unowned var addr in ar) ar2 [i++] = Address (addr.address, addr.port);
          return (owned) ar2;
        }

      public async KeyRef[] list_ids (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var ar = (Key[]) role_provider.locals ();
          var ar2 = new KeyRef [ar.length];
          int i = 0;

          foreach (unowned var key in ar) ar2 [i++] = KeyRef (key.bytes);
          return (owned) ar2;
        }
    }

  public class RoleSkeleton : GLib.Object, Kademlia.DBus.Role
    {
      public AddressProvider address_provider { get; construct; }
      public AddressRegistry address_registry { get; construct; }
      public string name { get; construct; }
      public RoleProvider role_provider { get; construct; }
      public ValuePeer value_peer { get; construct; }

      public Kademlia.DBus.KeyRef id { owned get { return KeyRef (value_peer.id.bytes); } }
      public string role { owned get { return _name; } }

      public RoleSkeleton (AddressProvider address_provider, AddressRegistry address_registry, string name, RoleProvider role_provider, ValuePeer value_peer)
        {
          Object (address_provider : address_provider, address_registry : address_registry, name : name, role_provider : role_provider, value_peer : value_peer);
        }

      public async PeerRef[] find_node (PeerRef from_, KeyRef key, GLib.Cancellable? cancellable) throws GLib.Error
        {
          var from = know (from_);
          var id = new Key.verbatim (key.value);
          var re = yield value_peer.find_peer_complete (from, id, cancellable);
          var ar = new PeerRef [re.length];

          for (int i = 0; i < ar.length; ++i) ar [i] = PeerRef (re [i].bytes, address_provider.lookup (re [i]));
          return (owned) ar;
        }

      public async ValueRef find_value (PeerRef from_, KeyRef key, GLib.Cancellable? cancellable) throws GLib.Error
        {
          var from = know (from_);
          var id = new Key.verbatim (key.value);
          var value = yield value_peer.find_value_complete (from, id, cancellable);

          if (value.is_inmediate)

            return ValueRef.inmediate (value.value);
          else
            {
              var ks = (Key[]) value.steal_keys ();
              var ar = new PeerRef [ks.length];

              for (int i = 0; i < ks.length; ++i) ar [i] = PeerRef (ks [i].bytes, address_provider.lookup (ks [i]));
              return ValueRef.delegated ((owned) ar);
            }
        }

      public Key know (PeerRef? ref_)
        {
          Key? id = null;

          if (ref_.knowable)
            {
              id = new Key.verbatim (ref_.id.value);
              address_registry.add (id, ref_.addresses);
            }

          return (owned) id;
        }

      public async bool store (PeerRef from_, KeyRef key, GLib.Variant variant, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          GLib.Value value;
          GValr.net2nat (out value, variant);

          var from = know (from_);
          var id = (Key) new Key.verbatim (key.value);

          return yield value_peer.store_value_complete (from, id, value, cancellable);
        }

      public async bool ping (PeerRef from_, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var from = know (from_);
          return yield value_peer.ping_peer_complete (from, cancellable);
        }
    }
}
