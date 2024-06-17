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
  public class Application : GLib.Application
    {
      const string APPID = "org.hck.ScrapperD";

      private GLib.HashTable<string, GLib.TypeClass> modules;
      private ScrapperD.Hub hub;

      public static int main (string[] args)
        {
          unowned var extension_point = GLib.IOExtensionPoint.register (Instance.EXTENSION_POINT);
          unowned var extra_modules_dir = GLib.Environment.get_variable ("SCRAPPERD_EXTRA_MODULES");
          extension_point.set_required_type (typeof (Instance));

          if (extra_modules_dir != null) foreach (unowned var dir in extra_modules_dir.split (";"))
            {
              GLib.IOModule.scan_all_in_directory (dir);
            }

          return (new Application ()).run (args);
        }

      construct
        {
          modules = new HashTable<string, GLib.TypeClass> (GLib.str_hash, GLib.str_equal);

          foreach (unowned var extension in GLib.IOExtensionPoint.lookup (Instance.EXTENSION_POINT).get_extensions ())
            {

              modules.insert (extension.get_name (), extension.ref_class ());

              foreach (unowned var entry in ((InstanceClass) extension.ref_class ()).get_option_entries ())
                {
                  unowned var arg = entry.arg;
                  unowned var arg_data = entry.arg_data;
                  unowned var arg_description = entry.arg_description;
                  unowned var description = entry.description;
                  unowned var flags = entry.flags;
                  unowned var long_name = entry.long_name;
                  unowned var short_name = entry.short_name;

                  add_main_option (long_name, short_name, flags, arg, description, arg_description);
                }
            }

          add_main_option ("address", 'a', 0, GLib.OptionArg.STRING, "Address of entry node", "ADDRESS");
          add_main_option ("modules", 0, 0, GLib.OptionArg.NONE, "List installed modules", null);
          add_main_option ("port", 'p', 0, GLib.OptionArg.INT, "Port where to listen for peer hails", "PORT");
          add_main_option ("public", 0, 0, GLib.OptionArg.STRING_ARRAY, "Public addresses to publish", "ADDRESS");
          add_main_option ("role", 'r', 0, GLib.OptionArg.STRING_ARRAY, "Node role in the network (multiple roles allowed)", "ROLE");
          add_main_option ("version", 'V', 0, GLib.OptionArg.NONE, "Print version", null);
        }

      public Application ()
        {
          Object (application_id : APPID, flags : GLib.ApplicationFlags.HANDLES_COMMAND_LINE | GLib.ApplicationFlags.NON_UNIQUE);
        }

      public override void activate ()
        {
          base.activate ();
          message (@"application $(application_id) activated");
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

      private async void command_line_async (GLib.ApplicationCommandLine cmdline, GLib.Cancellable? cancellable = null)
        {
          unowned var options = cmdline.get_options_dict ();
          unowned var good = true;

          while (true)
            {
              GLib.VariantIter iter;
              int porti;
              string role;

              if (options.lookup ("port", "i", out porti) == false)

                hub = new Hub ();
              else
                {
                  if (porti >= uint16.MIN && porti < uint16.MAX)

                    hub = new Hub ((uint16) porti);
                  else
                    {
                      cmdline.printerr ("invalid port %i\n", porti);
                      cmdline.set_exit_status (1);
                      break;
                    }
                }

              if (options.lookup ("public", "as", out iter))
                {
                  string address;

                  while (iter.next ("s", out address))
                    {
                      try { yield hub.add_public_address (address); } catch (GLib.Error e)
                        {
                          critical (@"$(e.domain): $(e.code): $(e.message)");
                        }
                    }
                }

              if (options.lookup ("role", "as", out iter) == false)
                {
                  cmdline.printerr ("---role unspecified\n");
                  cmdline.set_exit_status (1);
                  break;
                }
              else while (iter.next ("s", out role))
                {
                  unowned GLib.TypeClass klass;

                  if (unlikely ((klass = modules.lookup (role)) == null))
                    {
                      good = false;
                      cmdline.printerr ("Unknown role '%s'\n", role);
                      cmdline.set_exit_status (1);
                      break;
                    }
                  else if (unlikely (klass.get_type ().is_a (typeof (Instance)) == false))
                    {
                      error ("Instance type doesn't derivates from %s", typeof (Instance).name ());
                    }
                  else
                    {
                      var gtype = klass.get_type ();
                      var instance = (Instance) GLib.Object.new (gtype, "hub", hub);

                      if (gtype.is_a (typeof (GLib.Initable)))
                        {
                          try { ((GLib.Initable) instance).init (cancellable); } catch (GLib.Error e)
                            {
                              cmdline.printerr ("%s: %u: %s\n", e.domain.to_string (), e.code, e.message);
                              cmdline.set_exit_status (1);
                              break;
                            }
                        }
                      else if (gtype.is_a (typeof (GLib.AsyncInitable)))
                        {
                          try { yield ((GLib.AsyncInitable) instance).init_async (GLib.Priority.DEFAULT, cancellable); } catch (GLib.Error e)
                            {
                              cmdline.printerr ("%s: %u: %s\n", e.domain.to_string (), e.code, e.message);
                              cmdline.set_exit_status (1);
                              break;
                            }
                        }

                      hub.add_instance (instance);
                    }
                }

              hold ();
              hub.begin ();
              break;
            }
        }

      public override int handle_local_options (GLib.VariantDict opts)
        {
          if (opts.contains ("modules"))
            {
              var builder = new StringBuilder ();
              var first = true;

              foreach (unowned var extension in GLib.IOExtensionPoint.lookup (Instance.EXTENSION_POINT).get_extensions ())
                {
                  builder.append_printf ("%s%s", first ? "" : ", ", extension.get_name ());
                  first = false;
                }

              if (first == false)
                {
                  builder.append_c ('\n');
                }

              print ("%s", builder.str);
              return 0;
            }
          else if (opts.contains ("version"))
            {
              print ("%s\n", Config.PACKAGE_VERSION);
              return 0;
            }
          return -1;
        }
    }
}
