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

[CCode (cprefix = "Scrapperd", lower_case_cprefix = "scrapperd_")]

namespace ScrapperD
{
  public class Connection : GLib.Object, GLib.AsyncInitable
    {
      public string address { get; construct; }
      public GLib.DBusConnection bus { get; private set; }
      public GLib.DBusAuthObserver? observer { get; construct; default = null; }
      public Array<uint> objects = new Array<int> ();
      public Array<uint> subscriptions = new Array<int> ();

      ~Connection ()
        {
          foreach (uint registration_id in objects) bus.unregister_object (registration_id);
          foreach (uint subscription_id in subscriptions) bus.signal_unsubscribe (subscription_id);
        }

      public async Connection (string address, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          Object (address : address);
          yield init_async (GLib.Priority.DEFAULT, cancellable);
        }

      public async bool close (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          return yield bus.close (cancellable);
        }

      public async T get_proxy<T> (string? name, string path, GLib.DBusProxyFlags flags = 0, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          return yield bus.get_proxy<T> (name, path, flags, cancellable);
        }

      public uint register_object<T> (string path, T instance) throws GLib.Error
        {
          uint id;
          objects.append_val (id = bus.register_object<T> (path, instance));
          return id;
        }

      public uint signal_subscribe (string? sender, string? interface_name, string? member, string? object_path, string? arg0, GLib.DBusSignalFlags flags, owned GLib.DBusSignalCallback callback)
        {
          uint id;
          subscriptions.append_val (id = bus.signal_subscribe (sender, interface_name, member, object_path, arg0, flags, (owned) callback));
          return id;
        }

      public async bool init_async (int priority, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var flags1 = GLib.DBusConnectionFlags.AUTHENTICATION_CLIENT;
          var flags2 = GLib.DBusConnectionFlags.MESSAGE_BUS_CONNECTION;
          var flags = flags1 | flags2;

          bus = yield new GLib.DBusConnection.for_address (address, flags, observer, cancellable);
          return true;
        }
    }
}
