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
  public struct Address
    {
      public string address;
      public uint16 port;

      public Address (owned string address, uint16 port)
        {
          this.address = (owned) address;
          this.port = port;
        }

      public static bool equal (Address? a, Address? b)
        {
          return a.port == b.port && GLib.str_equal (a.address, b.address);
        }

      public static uint hash (Address? a)
        {
          int a_ = a.port;
          return GLib.int_hash (a_) ^ GLib.str_hash (a.address);
        }
    }

  public interface AddressProvider : GLib.Object
    {
      public abstract bool has (Key id);
      public abstract Address[] locals ();
      public abstract Address[] lookup (Key id);
    }
}
