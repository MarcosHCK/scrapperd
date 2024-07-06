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
  public abstract class Application : GLib.Application
    {
      public Kademlia.DBus.Hub hub { get; private construct; }

      construct
        {
          hub = new Kademlia.DBus.Hub ();
          add_main_option ("address", 'a', 0, GLib.OptionArg.STRING_ARRAY, "Address of entry node", "ADDRESS");
          add_main_option ("port", 'p', 0, GLib.OptionArg.INT, "Port where to listen for peer hails", "PORT");
          add_main_option ("public", 0, 0, GLib.OptionArg.STRING_ARRAY, "Public addresses to publish", "ADDRESS");
          add_main_option ("version", 'V', 0, GLib.OptionArg.NONE, "Print version", null);
        }

      protected Application (string application_id, GLib.ApplicationFlags flags)
        {
          Object (application_id : application_id, flags : flags | GLib.ApplicationFlags.HANDLES_COMMAND_LINE);
        }

      public override int command_line (GLib.ApplicationCommandLine cmdline)
        {
          hold ();

          command_line_async.begin (cmdline, null, (app, res) =>
            {
              ((Application) app).command_line_async.end (res);
              release ();
            });

          return base.command_line (cmdline);
        }

      protected virtual async bool command_line_async (GLib.ApplicationCommandLine cmdline, GLib.Cancellable? cancellable = null)
        {
          unowned var options = cmdline.get_options_dict ();
          unowned var good = true;

          while (true)
            {
              int option_i;
              string option_s;
              GLib.VariantIter iter;

              var addresses = new GLib.SList<string> ();
              var entries = new GLib.SList<string> ();
              var port = (uint16) 0;//Kademlia.DBus.Hub.DEFAULT_PORT;

              if (options.lookup ("address", "as", out iter)) while (iter.next ("s", out option_s))
                {
                  entries.prepend ((owned) option_s);
                }

              if (options.lookup ("port", "i", out option_i))
                {
                  if (option_i >= uint16.MIN && option_i < uint16.MAX)

                    port = (uint16) option_i;
                  else
                    {
                      good = false;
                      cmdline.printerr ("invalid port %i\n", option_i);
                      cmdline.set_exit_status (1);
                      break;
                    }
                }

              if (options.lookup ("public", "as", out iter)) while (iter.next ("s", out option_s))
                {
                  addresses.prepend ((owned) option_s);
                }

              if (unlikely (good == false)) break;

              hold ();
              break;
            }

          return good;
        }

      protected virtual async bool register_on_hub_async () throws GLib.Error
        {
          return true;
        }

      public override int handle_local_options (GLib.VariantDict options)
        {
          if (options.contains ("version"))
            {
              print ("%s\n", Config.PACKAGE_VERSION);
              return 0;
            }

          return base.handle_local_options (options);
        }
    }
}
