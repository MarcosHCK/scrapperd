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
  internal const string ROLE = "scrapper";

  public class ScrapperInstance : Instance
    {
      public override string role { get { return ROLE; } }

      public override KademliaDBus.Peer get_peer ()
        {
          return new KademliaDBus.Peer (ROLE, new Store ());
        }

      [ModuleInit]
      [CCode (cname = "g_io_scrappermod_load")] public static void load (GLib.IOModule module)
        {
          module.set_name (ROLE);
          Instance.install<ScrapperInstance> (ROLE, ">=" + Config.PACKAGE_VERSION);
        }

      [CCode (cname = "g_io_scrappermod_query")] public static string[] query ()
        {
          var extension_points = new string[] { Instance.EXTENSION_POINT };
          return extension_points;
        }

      [CCode (cname = "g_io_scrappermod_unload")] public static void unload (GLib.IOModule module)
        {
        }
    }
}