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

[CCode (cheader_filename = "netifaces.h", lower_case_cprefix = "adv_net_ifaces_")]

namespace Advertise.NetIfaces
{
  [Compact (opaque = false)]

  public class Info
    {
      private Info ();
      public GLib.SocketAddress? address;
      public bool loopback;
      public string name;
      public GLib.SocketAddress? netmask;
      public bool ppp;
      public GLib.SocketAddress? broadcast { get; }
      public GLib.SocketAddress? peer { get; }
    }

  [CCode (array_length = false, array_null_terminated = true)]
  public static Info[] enumerate (GLib.SocketFamily family) throws GLib.Error;
}
