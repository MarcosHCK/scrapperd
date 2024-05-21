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
  [DBus (name = "org.freedesktop.DBus")]
  private interface DBus : GLib.Object
    {
      public const string BUS_NAME = "org.freedesktop.DBus";
      public const string OBJECT_PATH = "/org/freedesktop/DBus";

      public abstract async string[] ListNames () throws GLib.Error;
      public signal void NameOwnerChanged (string name, string old_owner, string new_owner);
    }

  public class DBusBridge : GLib.Object, GLib.AsyncInitable
    {
      public GLib.DBusConnection dst_connection { get; construct; }
      public GLib.DBusConnection src_connection { get; construct; }
      public string prefix { get; construct; }

      private DBus controller;
      private HashTable<string, uint> names;
      private uint next_major = 0;
      private uint next_minor = 0;

      construct
        {
          names = new HashTable<string, uint> (GLib.str_hash, GLib.str_equal);
        }

      public async DBusBridge (GLib.DBusConnection dst_connection, GLib.DBusConnection src_connection, string prefix, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          Object (dst_connection : dst_connection, src_connection : src_connection, prefix : prefix);
          yield init_async (GLib.Priority.DEFAULT, cancellable);
        }

      public async bool init_async (int io_priority, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          controller = yield src_connection.get_proxy<DBus> (DBus.BUS_NAME, DBus.OBJECT_PATH, 0, cancellable);
          return true;
        }

      public string next_name ()
        {
          var suffix = next_minor < uint.MAX ? @"$(next_major).$(next_minor++)" : @"$(next_major++).$(next_minor = 0)";
          var name = @"p$(prefix.offset (1)).c$(suffix.replace (".", ".c"))";
          return name;
        }
    }
}
