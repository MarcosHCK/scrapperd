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
using Kademlia.DBus;

[CCode (cprefix = "KAd", lower_case_cprefix = "k_ad_")]

namespace Kademlia.Ad
{
  public static async bool join (Hub hub, Protocol proto, GLib.Cancellable? cancellable = null) throws GLib.Error

      requires (proto.addresses != null)
      requires (proto.role != null)
    {
      unowned var id = proto.id;

      if (hub.has_contact (id) == false && hub.has_local (id) == false)
        {
          var addresses = new Address [proto.addresses.length];
          int i = 0;

          foreach (unowned var address in proto.addresses) addresses [i++] = address;
          hub.add_contact_addresses (proto.id, addresses);

          yield hub.join (id, proto.role, cancellable);
        }
      return true;
    }
}
