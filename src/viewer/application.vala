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
      const string joinproto_vaddr = "sq";
      const string joinproto_vtuple = "(" + joinproto_vaddr + ")";
      const string joinproto_varray = "a" + joinproto_vtuple;
      const string joinproto_vtype = "(s" + joinproto_varray + ")";
      private Advertise.Hub adv_hub;
      private Advertise.Peeker adv_peeker;
      private GenericSet<unowned Kademlia.Key> adv_peers;
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
          add_action ("jointos", GLib.VariantType.STRING_ARRAY, (a, p) => jointos_action (p.dup_strv ()));
          add_action ("jointo_p", GLib.VariantType.STRING, (a, p) => jointo_action (p.get_string (null)));
          add_action ("joinproto", new GLib.VariantType (joinproto_vtype), (a, p) => joinproto (p));
          add_action ("quit", null, () => quit ());

          add_main_option ("address", 'a', 0, GLib.OptionArg.STRING_ARRAY, "Network entry point", "ADDRESS");
          add_main_option ("advertise-port", 0, 0, GLib.OptionArg.INT, "Advertise port", "PORT");
          add_main_option ("port", 'p', 0, GLib.OptionArg.INT, "Network public port", "PORT");

          adv_hub = new Advertise.Hub ();
          adv_peeker = new Advertise.Peeker (adv_hub);
          adv_peers = new GenericSet<unowned Kademlia.Key> (Kademlia.Key.hash, Kademlia.Key.equal);
          hub = new Kademlia.DBus.NetworkHub ();

          adv_hub.ensure_protocol (typeof (Kademlia.Ad.Protocol));
          adv_peeker.got_ad.connect (on_got_ad);
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

      private void added_ad (Kademlia.Ad.Protocol proto)
        {
          ApplicationWindow window;
          if ((window = active_window as ApplicationWindow) != null) added_ad_for (proto, window);
        }

      static void added_ad_for (Kademlia.Ad.Protocol proto, ApplicationWindow window)
        {
          var ad_row = new AdRow (proto);
          var self = (Application) window.application;
          var weak1 = WeakRef (window);
          var weak2 = WeakRef (self);

          self.adv_peers.add (proto.id);

          ad_row.close.connect (row =>
            {
              ((Application?) weak2.get ())?.adv_peers?.remove (proto.id);
              ((ApplicationWindow?) weak1.get ())?.remove_row (row);
            });

          ad_row.externalize.connect (row =>
            {
              Application application;
              ApplicationWindow window2;
              (application = ((Application) GLib.Application.get_default ()));
              (window2 = new ApplicationWindow (application)).present ();
              added_ad_for (proto, window2);
              ((ApplicationWindow?) weak1.get ())?.remove_row (row);
            });

          ad_row.join.connect (row =>
            {
              ((Application?) weak2.get ())?.adv_peers?.remove (proto.id);
              ((ApplicationWindow?) weak1.get ())?.remove_row (row);

              var window2 = (ApplicationWindow?) weak1.get ();
              var application = (Application?) window2?.application;
              var varray = new GLib.VariantType (joinproto_varray);
              var vtuple = new GLib.VariantType (joinproto_vtuple);
              var vtype = new GLib.VariantType (joinproto_vtype);
              var builder = new GLib.VariantBuilder (vtype);

              builder.add ("s", proto.role);
              builder.open (varray);

              if (proto.addresses == null)
                {
                  var error = new IOError.NETWORK_UNREACHABLE ("can not join to advertised node");
                  ((Application) weak2.get ()).notify_recoverable_error (error);
                }
              else
                {
                  foreach (unowned var address in proto.addresses)
                    {
                      builder.open (vtuple);
                      builder.add ("s", address.address);
                      builder.add ("q", address.port);
                      builder.close ();
                    }

                  builder.close ();
                  var action = application.lookup_action ("joinproto");
                  var parameter = builder.end ();

                  action?.activate (parameter);
                }
            });

          window.append_row (ad_row);
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
          var weak2 = WeakRef (window.application);

          role_dto.on_get.connect ((key, target) =>
            {
              on_role_dto_get.begin (role_proxy, key, target, null, (o, res) =>
                {
                  try { on_role_dto_get.end (res); } catch (GLib.Error e)
                    {
                      ((Application) weak2.get ()).notify_recoverable_error (e);
                    }
                });
            });

          role_dto.on_set.connect ((key, value) =>
            {
              on_role_dto_set.begin (role_proxy, key, value, null, (o, res) =>
                {
                  try { on_role_dto_set.end (res); } catch (GLib.Error e)
                    {
                      ((Application) weak2.get ()).notify_recoverable_error (e);
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

          var addresses = new GLib.List<string> ();
          var advertise_port = (uint16) Advertise.Ipv4Channel.DEFAULT_PORT;

          while (true)
            {
              GLib.VariantIter iter;
              GLib.List<JoinToProxy?> proxies;
              int option_i;
              string option_s;

              if (options.lookup ("address", "as", out iter)) while (iter.next ("s", out option_s))
                {
                  addresses.append ((owned) option_s);
                }

              if (options.lookup ("advertise-port", "i", out option_i))
                {
                  if (option_i >= uint16.MIN && option_i < uint16.MAX)

                    advertise_port = (uint16) option_i;
                  else
                    {
                      good = false;
                      cmdline.printerr ("invalid port %i\n", option_i);
                      cmdline.set_exit_status (1);
                      break;
                    }
                }

              try { adv_hub.add_channel (new Advertise.Ipv4Channel (advertise_port)); } catch (GLib.Error e)
                {
                  good = false;
                  cmdline.printerr ("%s: %u: %s\n", e.domain.to_string (), e.code, e.message);
                  cmdline.set_exit_status (1);
                  break;
                }

              activate ();

              foreach (unowned var address in addresses)
                {

                  try { proxies = yield jointo_async (address, cancellable); } catch (GLib.Error e)
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

              break;
            }

          if (likely (good == true))

            active_window.present ();
          else
            {
              active_window.close ();
              active_window.destroy ();
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
          jointo_async.begin (address, null, jointo_notify);
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

      static void jointo_notify (GLib.Object? o, GLib.AsyncResult res)
        {
          Application self = (Application) o;
          GLib.List<JoinToProxy?> proxies;

          try { proxies = self.jointo_async.end (res); } catch (GLib.Error e)
            {
              self.notify_recoverable_error (e);
              return;
            }

          self.jointo_notify_a (proxies);
        }

      private void jointo_notify_a (GLib.List<JoinToProxy?> proxies)
        {
          if (likely (proxies != null)) foreach (unowned var proxy in proxies)
            {
              unowned var role = proxy.role;
              unowned var role_proxy = proxy.role_proxy;

              added_role (role_proxy, role);
            }

          release ();
        }

      private void jointos_action (owned string[] addresses)
        {
          hold ();
          jointos_async.begin ((owned) addresses, null, jointos_notify);
        }

      private async GLib.List<JoinToProxy?> jointos_async (owned string[] addresses, GLib.Cancellable? cancellable) throws GLib.Error
        {
          foreach (unowned var address in addresses) try
            {
              return yield jointo_async (address, cancellable);
            }
          catch (GLib.IOError e)
            {
              switch (e.code)
                {
                  case GLib.IOError.CONNECTION_CLOSED:
                  case GLib.IOError.CONNECTION_REFUSED:
                  case GLib.IOError.NETWORK_UNREACHABLE:

                    continue;
                  default:
                    throw (owned) e;
                }
            }

          throw new GLib.IOError.NETWORK_UNREACHABLE ("can not join to advertised node");
        }

      static void jointos_notify (GLib.Object? o, GLib.AsyncResult res)
        {
          Application self = (Application) o;
          GLib.List<JoinToProxy?> proxies;

          try { proxies = self.jointos_async.end (res); } catch (GLib.Error e)
            {
              self.notify_recoverable_error (e);
              return;
            }

          self.jointo_notify_a (proxies);
        }

      private void joinproto (GLib.Variant p)
        {
          hold ();
          joinproto_async.begin (p, null, joinproto_notify);
        }

      private async GLib.List<JoinToProxy?> joinproto_async (GLib.Variant p, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          uint16 port;
          string address, role;
          GLib.SocketAddress? addr;
          GLib.VariantIter iter;

          p.get_child (0, "s", out role);
          p.get_child (1, joinproto_varray, out iter);

          while (iter.next (joinproto_vtuple, out address, out port))
            {
              var network = GLib.NetworkAddress.parse (address, port);
              var enumeartor = network?.enumerate ();
              var addresses = new GenericArray<string> ();

              if (enumeartor != null) while ((addr = yield enumeartor.next_async (cancellable)) != null)
                {
                  if (addr is GLib.InetSocketAddress)

                    addresses.add (@"$(addr.to_string ())#$role");
                }

              try { return yield jointos_async (addresses.steal (), cancellable); } catch (GLib.IOError e)
                {
                  if (e.code != GLib.IOError.NETWORK_UNREACHABLE)

                    throw (owned) e;
                }
            }

          throw new GLib.IOError.NETWORK_UNREACHABLE ("can not join to advertised node");
        }

      static void joinproto_notify (GLib.Object? o, GLib.AsyncResult res)
        {
          Application self = (Application) o;
          GLib.List<JoinToProxy?> proxies;

          try { proxies = self.joinproto_async.end (res); } catch (GLib.Error e)
            {
              self.notify_recoverable_error (e);
              return;
            }

          self.jointo_notify_a (proxies);
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

      private void on_got_ad (Advertise.Ad ad)
        {
          foreach (unowned var proto_ in ad.protocols) if (proto_.name == Kademlia.Ad.Protocol.PROTO_NAME)
            {
              unowned var proto = (Kademlia.Ad.Protocol) proto_;
              unowned bool added;
                added = adv_peers.contains (proto.id);
                added = added || hub.has_contact (proto.id);
                added = added || hub.has_local (proto.id);
              if (added == false) added_ad (proto);
            }
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
