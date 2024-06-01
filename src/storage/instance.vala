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
  internal const string ROLE = "storage";

  public class StorageInstance : Instance
    {
      private Kademlia.Node? node = null;
      private uint iface_regid = 0;

      ~StorageInstance ()
        {
          connection.unregister_object (iface_regid);
        }

      [CCode (cname = "g_io_storagemod_query")]
      public static string[] query ()
        {
          var extension_points = new string[] { Instance.EXTENSION_POINT };
          return extension_points;
        }

      [ModuleInit]
      [CCode (cname = "g_io_storagemod_load")]
      public static void load (GLib.IOModule module)
        {
          module.set_name (ROLE);
          Instance.install<StorageInstance> (ROLE, ">=" + Config.PACKAGE_VERSION);
        }

      [CCode (cname = "g_io_storagemod_unload")]
      public static void unload (GLib.IOModule module)
        {
        }

      public override void activate ()
        {
          try
            {
              node = node != null ? node : new Kademlia.Node ();
              iface_regid = connection.register_object<Storage> (Node.BASE_PATH, new StorageImpl (node));
              connection.on_closed.connect (() => unref ());
              @ref ();
            }
          catch (GLib.Error e)
            {
              critical (@"$(e.domain): $(e.code): $(e.message)");
            }
        }
    }
}
