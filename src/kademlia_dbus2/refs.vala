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
  public struct KeyRef
    {
      public uint8[] value;

      public KeyRef (owned uint8[] value)
        {
          this.value = (owned) value;
        }
    }

  public struct PeerRef
    {
      Address[]? addresses;
      KeyRef? id;
      bool knowable;

      public PeerRef (owned uint8[] id, owned Address[] addresses)
        {
          this.addresses = (owned) addresses;
          this.id = KeyRef ((owned) id);
          this.knowable = true;
        }

      public PeerRef.anonymous (owned uint8[] id)
        {
          this.id = KeyRef ((owned) id);
          this.knowable = false;
        }
    }

  public struct ValueRef
    {
      bool found;
      PeerRef[]? others;
      Variant? value;

      public ValueRef.delegated (owned PeerRef[] others)
        {
          this.found = false;
          this.others = (owned) others;
          this.value = new Variant.byte (0);
        }

      public ValueRef.inmediate (owned GLib.Value? value)
        {
          this.found = true;
          this.value = GValr.nat2net (value);
        }

      public GLib.Value? get_value ()
        {
          GLib.Value value;
          GValr.net2nat (out value, this.value);
          return (owned) value;
        }
    }
}
