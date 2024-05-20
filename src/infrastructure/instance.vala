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
      private string dbus_daemon = "scrapperd-bus";
      private uint16 dbus_port = 9000;

      private GLib.DBusConnection connection;
      private GLib.SubprocessLauncher launcher;

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
          try { launch_daemon (); } catch (GLib.Error e)
            {
              error (@"Can not launch dbus daemon: $(e.domain): $(e.code): $(e.domain)");
            }
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

      private async void connect_daemon (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var family = GLib.SocketFamily.IPV6;
          var inet_address = new InetAddress.loopback (family);
          var socket_address = new InetSocketAddress (inet_address, dbus_port);
          var client = new SocketClient ();

          client.enable_proxy = false;
          client.family = family;
          client.protocol = GLib.SocketProtocol.TCP;
          client.type = GLib.SocketType.STREAM;

          var flags1 = GLib.DBusConnectionFlags.AUTHENTICATION_CLIENT;
          var flags2 = GLib.DBusConnectionFlags.MESSAGE_BUS_CONNECTION;
          var flags = flags1 | flags2;
          var stream = yield client.connect_async (socket_address, cancellable);

          connection = yield new GLib.DBusConnection (stream, null, flags, null, cancellable);

          connection.register_object<Node> (Node.BASE_PATH, new NodeImpl ());
          connection.register_object<InstanceNode> (Node.BASE_PATH, new InstanceNodeImpl ());
        }

      private bool connect_daemon_source ()
        {
          connect_daemon.begin (null, (_, res) =>
            {
              try { connect_daemon.end (res); } catch (GLib.Error e)
                {
                  error (@"Can not connect to bus: $(e.domain): $(e.code): $(e.message)");
                }
            });
          return GLib.Source.REMOVE;
        }

      private void launch_daemon () throws GLib.Error
        {
          Subprocess process;
          Source source;

          launcher = new SubprocessLauncher (0);
          process = launcher.spawn (dbus_daemon, "--address", @"tcp:port=$(dbus_port)");
          source = new TimeoutSource (boottime);

          source.set_callback (() => connect_daemon_source ());
          source.set_priority (GLib.Priority.HIGH_IDLE);
          source.set_static_name ("ScrapperD.InfrastructureInstance.connect_daemon");
          source.attach (GLib.MainContext.get_thread_default ());

          process.wait_check_async.begin (null, (source_object, res) =>
            {

              try { ((GLib.Subprocess) source_object).wait_check_async.end (res); } catch (GLib.Error e)
                {
                  warning (@"D-Bus daemon: $(e.domain): $(e.code): $(e.message)");
                }

              try { launch_daemon (); } catch (GLib.Error e)
                {
                  error (@"Can not launch dbus daemon: $(e.domain): $(e.code): $(e.domain)");
                }
            });
        }
    }
}
