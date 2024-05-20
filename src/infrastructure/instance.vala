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
      private string? connection_address;
      private int boottime = 300;
      private string dbus_daemon = "scrapperd-bus";
      private uint16 dbus_port = 9000;

      private ScrapperD.Connection? client_connection = null;
      private ScrapperD.Connection? daemon_connection = null;

      private class NodeImpl : GLib.Object, Node
        {
          public string impl { owned get { return "org.hck.ScrapperD.Node.Infrastructure"; } }
          public string role { owned get { return ROLE; } }
        }

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
          add_option_entry ("boottime", 0, 0, GLib.OptionArg.INT, "Time to wait until dbus boots up", "MILLISECONDS");
          add_option_entry ("dbus-daemon", 0, 0, GLib.OptionArg.STRING, "D-Bus daemon to use", "COMMAND");
          add_option_entry ("dbus-port", 'p', 0, GLib.OptionArg.INT, "Port to listen to", "PORT");
        }

      public override void activate ()
        {
          launch_daemon.begin (null);
        }

      public override bool command_line (GLib.VariantDict opts) throws GLib.Error
        {
          string value_s;
          int value_i;

          if (opts.lookup ("boottime", "i", out value_i))
            {
              if (unlikely ((boottime = value_i) < 0))

                throw new IOError.FAILED ("invalid boottime value");
            }

          if (opts.lookup ("connect", "s", out value_s))
            {
              connection_address = value_s;
            }

          if (opts.lookup ("dbus-daemon", "s", out value_s))
            {
              dbus_daemon = value_s;
            }

          if (opts.lookup ("dbus-port", "i", out value_i))
            {
              if (likely (value_i >= uint16.MIN && uint16.MAX >= value_i))
                dbus_port = (uint16) value_i;
              else
                throw new IOError.FAILED ("invalid dbus port value");
            }
          return true;
        }

      private async void connect_client (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          if (connection_address != null)
            {
              var bus = yield new ScrapperD.Connection (connection_address, cancellable);

              bus.register_object<Node> (Node.BASE_PATH, new NodeImpl ());
              bus.register_object<InstanceNode> (Node.BASE_PATH, new InstanceNodeImpl (false));
              client_connection = bus;
            }
        }

      private bool connect_client_source ()
        {
          connect_client.begin (null, (_, res) =>
            {
              try { connect_client.end (res); } catch (GLib.Error e)
                {
                  error (@"Can not connect to bus: $(e.domain): $(e.code): $(e.message)");
                }
            });
          return GLib.Source.REMOVE;
        }

      private async void connect_daemon (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var address = @"tcp:host=localhost,port=$(dbus_port)";
          var bus = yield new ScrapperD.Connection (address, cancellable);

          bus.register_object<Node> (Node.BASE_PATH, new NodeImpl ());
          bus.register_object<InstanceNode> (Node.BASE_PATH, new InstanceNodeImpl (true));
          daemon_connection = bus;
        }

      private bool connect_daemon_source ()
        {
          connect_daemon.begin (null, (_, res) =>
            {
              try { connect_daemon.end (res); } catch (GLib.Error e)
                {
                  error (@"Can not connect to bus: $(e.domain): $(e.code): $(e.message)");
                }
              finally
                {
                  var source = new TimeoutSource (boottime);

                  source.set_callback (() => connect_client_source ());
                  source.set_priority (GLib.Priority.HIGH_IDLE);
                  source.set_static_name ("ScrapperD.InfrastructureInstance.connect_client");
                  source.attach (GLib.MainContext.get_thread_default ());
                }
            });
          return GLib.Source.REMOVE;
        }

      private async ScrapperD.Connection? destroy_connection (ScrapperD.Connection? dbus, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          if (likely (dbus != null)) try { yield dbus.close (cancellable); } catch (GLib.Error e)
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

          string args[] = { dbus_daemon, "--address", @"tcp:port=$(dbus_port)", null };

          do
            {
              try { process = launcher.spawnv (args); } catch (GLib.Error e)
                {
                  error (@"Can not launch dbus daemon: $(e.domain): $(e.code): $(e.domain)");
                }

              var source = new TimeoutSource (boottime);

              source.set_callback (() => connect_daemon_source ());
              source.set_priority (GLib.Priority.HIGH_IDLE);
              source.set_static_name ("ScrapperD.InfrastructureInstance.connect_daemon");
              source.attach (GLib.MainContext.get_thread_default ());

              try { yield process.wait_check_async (cancellable); } catch (GLib.Error e)
                {
                  client_connection = yield destroy_connection (client_connection, cancellable);
                  daemon_connection = yield destroy_connection (daemon_connection, cancellable);
                  warning (@"D-Bus daemon: $(e.domain): $(e.code): $(e.message)");
                }
            }
          while (cancellable?.is_cancelled () != true);
        }
    }
}
