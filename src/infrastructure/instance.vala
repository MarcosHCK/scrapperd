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
      private int sleep_time = 3 * 1000;

      [CCode (cname = "g_io_infrastructuremod_query")]
      public static string[] query ()
        {
          var extension_points = new string[] { Instance.EXTENSION_POINT };
          return extension_points;
        }

      [ModuleInit]
      [CCode (cname = "g_io_infrastructuremod_load")]
      public static void load (GLib.IOModule module)
        {
          module.set_name ("Infrastructure");
          Instance.install<InfrastructureInstance> ("infrastructure", ">=" + Config.PACKAGE_VERSION);
        }

      [CCode (cname = "g_io_infrastructuremod_unload")]
      public static void unload (GLib.IOModule module)
        {
        }

      class construct
        {
          add_option_entry ("sleep-time", 0, 0, GLib.OptionArg.INT, "Time to wait between watches", "MILLISECONDS");
        }

      public override void activate ()
        {
          var source = new GLib.TimeoutSource (sleep_time);

          source.set_callback (() => this.watch ());
          source.set_priority (GLib.Priority.DEFAULT_IDLE);
          source.set_static_name ("ScrapperD.InfrastructureInstance.watch");
          source.set_ready_time (0);
          source.attach (GLib.MainContext.get_thread_default ());
        }

      public override bool command_line (GLib.VariantDict dict) throws GLib.Error
        {
          if (dict.lookup ("sleep-time", "i", out sleep_time) && sleep_time < 0)
            {
              throw new IOError.FAILED ("invalid --sleep-time value");
            }
          return true;
        }

      public bool watch ()
        {
          print ("watch\n");
          return GLib.Source.CONTINUE;
        }
    }
}
