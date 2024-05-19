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
  public class InfrastructureInstance : Instance
    {
      [ModuleInit]
      [CCode (cname = "g_io_infrastructuremod_load")]
      public static void load (GLib.IOModule module)
        {
          module.set_name ("Infrastructure");
          Instance.install<InfrastructureInstance> ("infrastructure");
        }

      [CCode (cname = "g_io_infrastructuremod_unload")]
      public static void unload (GLib.IOModule module)
        {
        }
    }
}
