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
  public class Hub : GLib.Object
    {
      public AddressService address_service { get; construct; }
      public SocketRoleService role_service { get; construct; }

      construct
        {
          address_service = new AddressService ();
          role_service = new SocketRoleService (address_service);
        }

      ~Hub ()
        {
          role_service.drop_all ();
        }

      public async void add_local_address (string host_and_port, uint16 default_port, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var network_address = GLib.NetworkAddress.parse (host_and_port, default_port);
          var address_enumerator = network_address.enumerate ();
          var address = (GLib.SocketAddress?) null;

          while ((address = yield address_enumerator.next_async (cancellable)) != null)
            {
              var protocol = GLib.SocketProtocol.TCP;
              var type = GLib.SocketType.STREAM;

              role_service.listen_on_address (address, type, protocol);
            }
        }

      public void add_local_peer (string role, Key? id, ValueStore value_store)
        {
          unowned AddressProvider address_provider = address_service;
          unowned AddressRegistry address_registry = address_service;
          unowned LocalRegistry local_registry = role_service;
          unowned RoleProvider role_provider = role_service;
          unowned RoleRegistry role_registry = role_service;
          var peer = new PeerImpl (address_provider, id, address_registry, role_provider, role_registry, value_store);

          debug ("exposing peer %s:%s", role, peer.id.to_string ());
          local_registry.add (role, peer);
        }

      public void add_local_port (uint16 port, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          role_service.listen_on_port (port, cancellable);
        }

      public void start () { role_service.start (); }
      public void stop () { role_service.stop (); }
    }
}
