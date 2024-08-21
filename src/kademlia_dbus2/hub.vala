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
      public RoleService role_service { get; construct; }

      ~Hub ()
        {
          role_service.drop_all ();
        }

      public async ValuePeer create_proxy (string role, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          unowned AddressProvider address_provider = address_service;
          unowned AddressRegistry address_registry = address_service;
          unowned RoleProvider role_provider = role_service;
          unowned RoleRegistry role_registry = role_service;
          var peers = (Key[]) role_service.remotes ();
          var proxy = new PeerImplProxy (address_provider, null, address_registry, role_provider, role_registry);
          foreach (unowned var to in peers) yield proxy.join (to, cancellable);
          return proxy;
        }

      public async bool join (Key id, string role, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var locals = new List<unowned Local?> ();
          int any = 0;

          role_service.foreach_local ((i, r, p) => locals.append (Local (r, p)));

          foreach (unowned var local in locals) if (local.role == role) any += (yield local.peer.join (id, cancellable)) ? 1 : 0;
          return any > 0;
        }
    }
}
