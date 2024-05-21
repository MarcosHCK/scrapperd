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
  internal const string ROLE = "infrastructure";

  public class InfrastructureInstance : Instance
    {
      private int boottime = 300;
      private string daemon = "scrapperd-bus";
      private uint16 port = 9000;

      public GLib.DBusConnection? daemon_connection { get; private set; }

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
          module.set_name (ROLE);
          Instance.install<InfrastructureInstance> (ROLE, ">=" + Config.PACKAGE_VERSION);
        }

      [CCode (cname = "g_io_infrastructuremod_unload")]
      public static void unload (GLib.IOModule module)
        {
        }

      class construct
        {
          add_option_entry ("boottime", 0, 0, GLib.OptionArg.INT, "Time to wait until daemon boots up", "MILLISECONDS");
          add_option_entry ("daemon", 0, 0, GLib.OptionArg.STRING, "D-Bus daemon to use", "COMMAND");
          add_option_entry ("port", 'p', 0, GLib.OptionArg.INT, "Port to listen to", "PORT");
        }

      public override void activate ()
        {
          launch_daemon.begin (null);
        }

      public override bool command_line (GLib.VariantDict dict) throws GLib.Error
        {
          string value_s;
          int value_i;

          if (dict.lookup ("boottime", "i", out value_i))
            {
              if (unlikely ((boottime = value_i) < 0))

                throw new IOError.FAILED ("invalid boottime value");
            }

          if (dict.lookup ("daemon", "s", out value_s))
            {
              daemon = value_s;
            }

          if (dict.lookup ("port", "i", out value_i))
            {
              if (likely (value_i >= uint16.MIN && uint16.MAX >= value_i))

                port = (uint16) value_i;
              else
                throw new IOError.FAILED ("invalid dbus port value");
            }
          return base.command_line (dict);
        }

      private async bool connect_to_daemon (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var address = @"tcp:host=localhost,port=$(port)";
          var flags1 = GLib.DBusConnectionFlags.AUTHENTICATION_CLIENT;
          var flags2 = GLib.DBusConnectionFlags.MESSAGE_BUS_CONNECTION;
          var flags = flags1 | flags2;

          daemon_connection = yield new GLib.DBusConnection.for_address (address, flags, null, cancellable);
          return true;
        }

      private bool connect_to_daemon_source ()
        {
          connect_to_daemon.begin (null, (_, res) =>
            {
              try { connect_to_daemon.end (res); } catch (GLib.Error e)
                {
                  error (@"Can not connect back to daemon: $(e.domain): $(e.code): $(e.message)");
                }
            });
          return GLib.Source.REMOVE;
        }

      private static async GLib.DBusConnection? destroy_connection (GLib.DBusConnection? connection, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          if (likely (connection != null)) try { yield connection.close (cancellable); } catch (GLib.Error e)
            {
              if (e.matches (IOError.quark (), IOError.CANCELLED)) throw e;

                warning (@"Error closing connection: $(e.domain): $(e.code): $(e.message)");
            }
          return null;
        }

      private async void launch_daemon (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var launcher = new SubprocessLauncher (0);
          var process = (GLib.Subprocess) null;

          string args[] = { daemon, "--address", @"tcp:port=$(port)", null };

          do if (true)
            {
              try { process = launcher.spawnv (args); } catch (GLib.Error e)
                {
                  error (@"Can not launch dbus daemon: $(e.domain): $(e.code): $(e.domain)");
                }

              var source = new TimeoutSource (boottime);

              source.set_callback (() => connect_to_daemon_source ());
              source.set_priority (GLib.Priority.HIGH_IDLE);
              source.set_static_name ("ScrapperD.InfrastructureInstance.connect_daemon");
              source.attach (GLib.MainContext.get_thread_default ());

              try { yield process.wait_check_async (cancellable); } catch (GLib.Error e)
                {
                  daemon_connection = yield destroy_connection (daemon_connection);
                  warning (@"D-Bus daemon: $(e.domain): $(e.code): $(e.message)");
                }
            }
          while (cancellable?.is_cancelled () != true);
        }
    }
}
