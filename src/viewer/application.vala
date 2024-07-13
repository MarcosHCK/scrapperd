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

[CCode (cprefix = "ScrapperdViewer", lower_case_cprefix = "scrapperd_viewer_")]

namespace ScrapperD.Viewer
{
  const string APPID = "org.hck.ScrapperD.Viewer";

  public class Application : Gtk.Application
    {
      private Kademlia.DBus.NetworkHub hub;

      struct JoinToProxy
        {
          string role;
          Kademlia.ValuePeer role_proxy;

          public JoinToProxy (owned string role, owned Kademlia.ValuePeer role_proxy)
            {
              this.role = (owned) role;
              this.role_proxy = (owned) role_proxy;
            }
        }

      construct
        {
          add_action ("about", null, () => about_dialog ());
          add_action ("jointo", null, () => jointo_dialog ());
          add_action ("jointo_p", GLib.VariantType.STRING, (a, p) => jointo_action (p.get_string (null)));
          add_action ("quit", null, () => quit ());

          add_main_option ("address", 'a', 0, GLib.OptionArg.STRING_ARRAY, "Network entry point", "ADDRESS");
          add_main_option ("port", 'p', 0, GLib.OptionArg.INT, "Network public port", "PORT");

          hub = new Kademlia.DBus.NetworkHub ();
        }

      public Application ()
        {
          Object (application_id : APPID, flags : GLib.ApplicationFlags.HANDLES_COMMAND_LINE);
        }

      public static int main (string[] argv)
        {
          return (new Application ()).run (argv);
        }

      public override void activate ()
        {
          //Gtk.Window.set_interactive_debugging (true);
          new ApplicationWindow (this);
        }

      private new void add_action (string name, GLib.VariantType? parameter_type, owned GLib.SimpleActionActivateCallback callback)
        {
          GLib.SimpleAction action;
          (action = new GLib.SimpleAction (name, parameter_type)).activate.connect ((a, p) => callback (a, p));
          base.add_action (action);
        }

      private void added_role (Kademlia.ValuePeer role_proxy, string role)
        {
          ApplicationWindow window;
          if ((window = active_window as ApplicationWindow) != null) added_role_for (role_proxy, role, window);
        }

      static void added_role_for (Kademlia.ValuePeer role_proxy, string role, ApplicationWindow window, bool expand = false)
        {
          var role_dto = (Role) new Role ();
          var role_row = (RoleRow) new RoleRow (role_dto);
          var weak1 = WeakRef (window);

          role_dto.on_get.connect ((key, target) =>
            {
              on_role_dto_get.begin (role_proxy, key, target, null, (o, res) =>
                {
                  try { on_role_dto_get.end (res); } catch (GLib.Error e)
                    {
                      ((Application) GLib.Application.get_default ()).notify_recoverable_error (e);
                    }
                });
            });

          role_dto.on_set.connect ((key, value) =>
            {
              on_role_dto_set.begin (role_proxy, key, value, null, (o, res) =>
                {
                  try { on_role_dto_set.end (res); } catch (GLib.Error e)
                    {
                      ((Application) GLib.Application.get_default ()).notify_recoverable_error (e);
                    }
                });
            });

          role_row.close.connect (row =>
            {
              ((ApplicationWindow?) weak1.get ())?.remove_row (row);
            });

          role_row.externalize.connect (row =>
            {
              Application application;
              ApplicationWindow window2;
              (application = ((Application) GLib.Application.get_default ()));
              (window2 = new ApplicationWindow (application)).present ();
              added_role_for (role_proxy, role, window2, true);
              row.close ();
            });

          role_dto.id = role_proxy.id.to_string ();
          role_dto.role = role;
          role_row.expanded = expand;

          window.append_row (role_row);
        }

      Gtk.AboutDialog about;

      private void about_dialog ()
        {
          if (unlikely (about == null))
            {
              unowned var path = resource_base_path;

              about = new Gtk.AboutDialog ();

              about.hide.connect ((self) =>
                {
                  ((Gtk.Window) self).set_application (null);
                  ((Gtk.Window) self).set_transient_for (null);
                });
              
              try { about.artists = about_load_line_file (@"$path/about/artists"); } catch (GLib.Error e)
                {
                  error (@"$(e.domain): $(e.code): $(e.message)");
                }

              try { about.authors = about_load_line_file (@"$path/about/authors"); } catch (GLib.Error e)
                {
                  error (@"$(e.domain): $(e.code): $(e.message)");
                }

              try { about.documenters = about_load_line_file (@"$path/about/documenters"); } catch (GLib.Error e)
                {
                  error (@"$(e.domain): $(e.code): $(e.message)");
                }

              try { about.license = about_load_string_file (@"$path/about/license"); } catch (GLib.Error e)
                {
                  error (@"$(e.domain): $(e.code): $(e.message)");
                }

              try { about.logo = about_load_icon_file (@"$path/icons/logo"); } catch (GLib.Error e)
                {
                  error (@"$(e.domain): $(e.code): $(e.message)");
                }

              about.copyright = "Copyright 2024-2029";
              about.hide_on_close = true;
              about.license_type = Gtk.License.GPL_3_0;
              about.program_name = null;
              about.version = Config.PACKAGE_VERSION;
              about.website = Config.PACKAGE_URL;
              about.website_label = _ ("Visit out website");
              about.wrap_license = true;
            }

          about.set_application (this);
          about.present ();
        }

      static Gdk.Paintable about_load_icon_file (string path) throws GLib.Error
        {
          var bytes = GLib.resources_lookup_data (path, 0);
          var loader = new Gdk.PixbufLoader.with_type ("svg");
          loader.write_bytes (bytes);
          loader.close ();
          var pixbuf = loader.get_pixbuf ();
          var texture = Gdk.Texture.for_pixbuf (pixbuf);
          return texture;
        }

      static string[] about_load_line_file (string path) throws GLib.Error
        {
          var resource_stream = GLib.resources_open_stream (path, 0);
          var data_stream = new GLib.DataInputStream (resource_stream);
          var lines = new GenericArray<string> ();
          var line = (string?) null;
          while ((line = data_stream.read_line_utf8 ()) != null) lines.add (line);
          return lines.steal ();
        }

      static string about_load_string_file (string path) throws GLib.Error
        {
          var bytes = GLib.resources_lookup_data (path, 0);
          var data = bytes.get_data ();
          return ((string) data).substring (0, data.length);
        }

      public override int command_line (GLib.ApplicationCommandLine cmdline)
        {
          hold ();

          command_line_async.begin (cmdline, null, (o, res) =>
            {
              command_line_async.end (res);
              release ();
            });

          return base.command_line (cmdline);
        }

      private async bool command_line_async (GLib.ApplicationCommandLine cmdline, GLib.Cancellable? cancellable = null)
        {
          unowned var good = true;
          unowned var options = cmdline.get_options_dict ();

          while (true)
            {
              GLib.VariantIter iter;
              GLib.List<JoinToProxy?> proxies;
              string option_s;

              activate ();

              if (options.lookup ("address", "as", out iter)) while (iter.next ("s", out option_s))
                {

                  try { proxies = yield jointo_async (option_s, cancellable); } catch (GLib.Error e)
                    {
                      good = false;
                      cmdline.printerr ("%s: %u: %s\n", e.domain.to_string (), e.code, e.message);
                      cmdline.set_exit_status (1);
                      break;
                    }

                  foreach (unowned var proxy in proxies)
                    {
                      unowned var role = proxy.role;
                      unowned var role_proxy = proxy.role_proxy;

                      added_role (role_proxy, role);
                    }
                }

              if (unlikely (good == false))
                {
                  active_window.close ();
                  active_window.destroy ();
                  break;
                }

              active_window.present ();
              break;
            }

          return good;
        }

      private void jointo_dialog ()
        {
          var active_window = this.active_window;
          var join_dialog = new JoinDialog (this);

          join_dialog.action_name = "jointo_p";
          join_dialog.action_target = this;
          join_dialog.expecting = _ ("Address");

          join_dialog.set_transient_for (active_window);
          join_dialog.present ();
        }

      private void jointo_action (string address)
        {
          hold ();

          jointo_async.begin (address, null, (o, res) =>
            {
              GLib.List<JoinToProxy?>? proxies = null;

              try { proxies = jointo_async.end (res); } catch (GLib.Error e)
                {
                  notify_recoverable_error (e);
                }

              if (likely (proxies != null)) foreach (unowned var proxy in proxies)
                {
                  unowned var role = proxy.role;
                  unowned var role_proxy = proxy.role_proxy;

                  added_role (role_proxy, role);
                }

              release ();
            });
        }

      private async GLib.List<JoinToProxy?> jointo_async (string address, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          string[] elements;
          var default_port = Kademlia.DBus.NetworkHub.DEFAULT_PORT;
          var proxies = new GLib.List<JoinToProxy?> ();

          if ((elements = address.split ("#", -1)).length == 0)

            throw new UriError.FAILED ("empty address not valid");
          else
            {
              unowned var host_and_port = elements [0];

              for (unowned var i = 1; i < elements.length; ++i)
                {
                  var role = elements [i];
                  var proxy = yield hub.create_proxy_at (host_and_port, default_port, role, cancellable);

                  proxies.append (JoinToProxy ((owned) role, (owned) proxy));
                }
            }

          return (owned) proxies;
        }

      public void notify_desktop_error (GLib.Error error)
        {
          unowned var id1 = GLib.int_hash (error.code);
          unowned var id2 = GLib.str_hash (error.domain.to_string ());
          unowned var id3 = GLib.str_hash (error.message);
          unowned var id = id1 ^ id2 ^ id3;
          var notification = new GLib.Notification (@"$(error.domain) error");

          notification.set_body (@"Recoverable error: $(error.domain): $(error.code): $(error.message)");
          notification.set_icon (new GLib.ThemedIcon ("dialog-warning"));
          notification.set_priority (GLib.NotificationPriority.NORMAL);

          send_notification (@"$APPID-notification-$id", notification);
        }

      public void notify_recoverable_error (GLib.Error error)
        {
          ApplicationWindow window;

          if ((window = active_window as ApplicationWindow) == null)

            notify_desktop_error (error);
          else
            window.infobar.push_recoverable_error (error);
        }

      public void notify_unrecoverable_error (GLib.Error error)
        {
          ApplicationWindow window;

          if ((window = active_window as ApplicationWindow) == null)

            notify_desktop_error (error);
          else
            window.infobar.push_unrecoverable_error (error);
        }

      static async void on_role_dto_get (Kademlia.ValuePeer peer, owned RoleSource key_source, owned RoleTarget target_source, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var key = yield key_source.get_key ();
          var value = yield peer.lookup (key, cancellable);
          yield target_source.set_output (value, cancellable);
        }

      static async void on_role_dto_set (Kademlia.ValuePeer peer, owned RoleSource key_source, owned RoleSource value_source, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var key = yield key_source.get_key (cancellable);
          var value = yield value_source.get_input (cancellable);
          yield peer.insert (key, value, cancellable);
        }

      [CCode (cname = "gtk_style_context_add_provider_for_display")]

      static extern void _gtk_style_context_add_provider_for_display (Gdk.Display display, Gtk.StyleProvider provider, uint priority);

      public override void startup ()
        {
          base.startup ();

          var display = Gdk.Display.get_default ();
          var provider = new Gtk.CssProvider ();
          var priority = Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION;

          provider.parsing_error.connect ((section, error) =>
            {
              unowned var code = error.code;
              unowned var domain = error.domain.to_string ();
              unowned var message = error.message;
              var location = section.to_string ();

              critical ("css parsing error: %s: %s: %u: %s", location, domain, code, message);
            });

          provider.load_from_resource (@"$resource_base_path/gtk/styles.css");

          _gtk_style_context_add_provider_for_display (display, provider, priority);
        }
    }
}
