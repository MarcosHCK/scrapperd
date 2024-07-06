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
  [DBus (name = "org.hck.Kademlia.DBus.Node")]

  public interface Node : GLib.Object
    {
      public const string BASE_PATH = "/org/hck/Kademlia";
      [DBus (name = "ListAddresses")] public abstract async Address[] list_addresses (GLib.Cancellable? cancellable = null) throws GLib.Error;
      [DBus (name = "ListIds")] public abstract async KeyRef[] list_ids (GLib.Cancellable? cancellable = null) throws GLib.Error;
    }

  [DBus (name = "org.hck.Kademlia.DBus.Role")]

  public interface Role : GLib.Object
    {
      [DBus (name = "Id")] public abstract KeyRef id { owned get; }
      [DBus (name = "FindNode")] public abstract async PeerRef[] find_node (PeerRef from, KeyRef key, GLib.Cancellable? cancellable = null) throws GLib.Error;
      [DBus (name = "FindValue")] public abstract async ValueRef find_value (PeerRef from, KeyRef key, GLib.Cancellable? cancellable = null) throws GLib.Error;
      [DBus (name = "Role")] public abstract string role { owned get; }
      [DBus (name = "Store")] public abstract async bool store (PeerRef from, KeyRef key, GLib.Variant value, GLib.Cancellable? cancellable = null) throws GLib.Error;
      [DBus (name = "Ping")] public abstract async bool ping (PeerRef from, GLib.Cancellable? cancellable = null) throws GLib.Error;
    }
}
