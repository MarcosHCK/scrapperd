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
using KademliaDBus;

[CCode (cprefix = "ScrapperdViewer", lower_case_cprefix = "scrapperd_viewer_")]

namespace ScrapperD.Viewer
{
  const string APPID = "org.hck.ScrapperD.Viewer";

  public class Application : Gtk.Application
    {
      private Hub hub;
      private HashTable<string, PeerImplProxy> roles;

      construct
        {
          add_action ("about", null, () => about_dialog ());
          add_action ("jointo", null, () => jointo_dialog ());
          add_action ("jointo_p", GLib.VariantType.STRING, (a, p) => jointo_action (p.get_string (null)));
          add_action ("joinrole", null, () => joinrole_dialog ());
          add_action ("joinrole_p", GLib.VariantType.STRING, (a, p) => joinrole_action (p.get_string (null)));
          add_action ("quit", null, () => quit ());

          add_main_option ("address", 'a', 0, GLib.OptionArg.STRING_ARRAY, "Network entry point", "ADDRESS");

          roles = new HashTable<string, PeerImplProxy> (GLib.str_hash, GLib.str_equal);
        }

      public Application ()
        {
          Object (application_id : APPID, flags : GLib.ApplicationFlags.HANDLES_COMMAND_LINE);
        }

      public static int main (string[] argv)
        {
          typeof (ScrapperD.Viewer.ApplicationWindow).ensure ();
          typeof (ScrapperD.Viewer.InfoBar).ensure ();
          typeof (ScrapperD.Viewer.InfoBarMessage).ensure ();
          typeof (ScrapperD.Viewer.JoinDialog).ensure ();
          typeof (ScrapperD.Viewer.RoleRow).ensure ();

          return (new Application ()).run (argv);
        }

      public override void activate ()
        {
          ApplicationWindow window;
          Gtk.Window.set_interactive_debugging (true);

          (window = new ApplicationWindow (this)).present ();

          foreach (unowned var role in roles.get_keys ())

            added_role_for (role, window, true);
        }

      private new void add_action (string name, GLib.VariantType? parameter_type, owned GLib.SimpleActionActivateCallback callback)
        {
          GLib.SimpleAction action;
          (action = new GLib.SimpleAction (name, parameter_type)).activate.connect ((a, p) => callback (a, p));
          base.add_action (action);
        }

      private void added_role (string role)
        {
          ApplicationWindow window;

          if ((window = active_window as ApplicationWindow) != null)

            added_role_for (role, window);
        }

      private void added_role_for (string role, ApplicationWindow window, bool expand = false) requires (roles.contains (role))
        {
          var role_dto = (Role) new Role ();
          var role_row = (RoleRow) new RoleRow (role_dto); 
          var role_proxy = (PeerImpl) roles.lookup (role);
          var weak1 = WeakRef (role_proxy);
          var weak2 = WeakRef (window);

          role_dto.on_get.connect ((key, target) =>
            {
              on_role_dto_get.begin ((PeerImplProxy) weak1.get (), key, target, null, (o, res) =>
                {
                  try { on_role_dto_get.end (res); } catch (GLib.Error e)
                    {
                      ((Application) GLib.Application.get_default ()).notify_recoverable_error (e);
                    }
                });
            });

          role_dto.on_set.connect ((key, value) =>
            {
              on_role_dto_set.begin ((PeerImplProxy) weak1.get (), key, value, null, (o, res) =>
                {
                  try { on_role_dto_set.end (res); } catch (GLib.Error e)
                    {
                      ((Application) GLib.Application.get_default ()).notify_recoverable_error (e);
                    }
                });
            });

          role_row.close.connect ((row) =>
            {
              ((ApplicationWindow?) weak2.get ())?.remove_row (row);
            });

          role_row.externalize.connect ((row) =>
            {
              ApplicationWindow window2;
              (window2 = new ApplicationWindow (this)).present ();
              added_role_for (row.role.role, window2, true);
              row.close ();
            });

          role_row.expanded = expand;

          role_proxy.bind_property ("role", role_dto, "role", GLib.BindingFlags.SYNC_CREATE);
          role_proxy.bind_property ("id", role_dto, "id", GLib.BindingFlags.SYNC_CREATE, transform_id);
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
              if (command_line_async.end (res) == true)

                activate ();
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
              string option_s;

              if (options.lookup ("address", "as", out iter)) while (iter.next ("s", out option_s))

                try { yield jointo_async (option_s); } catch (GLib.Error e)
                  {
                    good = false;
                    cmdline.printerr ("%s: %u: %s\n", e.domain.to_string (), e.code, e.message);
                    cmdline.set_exit_status (1);
                    break;
                  }

              if (unlikely (good == false)) break;

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
              try { jointo_async.end (res); } catch (GLib.Error e)
                {
                  notify_recoverable_error (e);
                }

              release ();
            });
        }

      private async void jointo_async (string address, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          string[] elements;

          if ((elements = address.split ("#", -1)).length == 0)

            throw new UriError.FAILED ("empty address not valid");
          else
            {
              for (unowned var i = 1; i < elements.length; ++i)
                {
                  if (roles.lookup (elements [i]) != null)
                    continue;

                  var role = elements [i];
                  var proxy = new PeerImplProxy (role);

                  hub.add_peer (proxy);
                  roles.insert ((owned) role, (owned) proxy);
                }

              yield hub.join (elements [0], cancellable);
            }
        }

      private void joinrole_dialog ()
        {
          var active_window = this.active_window;
          var join_dialog = new JoinDialog (this);

          join_dialog.action_name = "joinrole_p";
          join_dialog.action_target = this;
          join_dialog.expecting = _ ("Role");

          join_dialog.set_transient_for (active_window);
          join_dialog.present ();
        }

      private void joinrole_action (string role)
        {
          if (roles.lookup (role) != null)
            {
              added_role (role);
              return;
            }

          hold ();

          joinrole_async.begin (role, null, (o, res) =>
            {
              try { joinrole_async.end (res); added_role (role); } catch (GLib.Error e)
                {
                  notify_recoverable_error (e);
                }

              release ();
            });
        }

      private async void joinrole_async (string role, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          PeerImplProxy proxy;
          hub.add_peer (proxy = new PeerImplProxy (role));
          roles.insert (role, (owned) proxy);
          yield hub.join (null, cancellable);
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

      static async void on_role_dto_get (PeerImplProxy peer, owned RoleSource key_source, owned RoleTarget target_source, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var key = yield key_source.get_key ();
          var value = yield peer.lookup (key, cancellable);
          yield target_source.set_output (value, cancellable);
        }

      static async void on_role_dto_set (PeerImplProxy peer, owned RoleSource key_source, owned RoleSource value_source, GLib.Cancellable? cancellable = null) throws GLib.Error
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

          hub = new Hub.offline ();

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

      static bool transform_id (GLib.Binding binding, GLib.Value source, ref GLib.Value target)

          requires (source.holds (typeof (Kademlia.Key)))
          requires (target.holds (typeof (string)))
        {
          target.set_string (((Kademlia.Key) source.get_boxed ()).to_string ());
          return true;
        }
    }
}
