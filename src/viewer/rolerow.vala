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
  [GtkTemplate (ui = "/org/hck/ScrapperD/Viewer/gtk/rolerow.ui")]

  public class RoleRow : Gtk.Grid, GLib.ActionGroup, GLib.ActionMap
    {
      [GtkChild] private unowned Gtk.EntryBuffer? entrybuffer1 = null;
      [GtkChild] private unowned Gtk.EntryBuffer? entrybuffer2 = null;
      [GtkChild] private unowned Gtk.EntryBuffer? entrybuffer3 = null;
      [GtkChild] private unowned Gtk.EntryBuffer? entrybuffer4 = null;
      [GtkChild] private unowned Gtk.Expander? expander1 = null;
      [GtkChild] private unowned Gtk.Label? label1 = null;
      private GLib.SimpleActionGroup actions;

      public Role role { get; construct; }
      public bool expanded { get { return expander1.expanded; } set { expander1.expanded = value; } }

      public signal void close ();
      public signal void externalize ();

      construct
        {
          insert_action_group ("row", actions = new GLib.SimpleActionGroup ());

          role.bind_property ("id", label1, "label", GLib.BindingFlags.SYNC_CREATE);
          role.bind_property ("role", expander1, "label", GLib.BindingFlags.SYNC_CREATE);

          add_action_ ("pick-file", new GLib.VariantType ("(sb)"), (a, p) =>
            {
              unowned var p1 = p.get_child_value (0).get_string ();
              unowned var p2 = p.get_child_value (1).get_boolean ();
              pickfile_dialog (p1, p2);
            });

          add_action_ ("with-type", new GLib.VariantType ("(ss)"), (a, p) =>
            {
              var p1 = p.get_child_value (0).get_string ();
              var p2 = p.get_child_value (1).get_string ();
              withtype_action (p1, p2);
            });
        }

      public RoleRow (Role role)
        {
          Object (role : role);
        }

      [CCode (array_length = false, array_null_terminated = true)]

      public new void activate_action (string action_name, GLib.Variant? parameter)
        {
          actions.activate_action (action_name, parameter);
        }

      public void add_action (GLib.Action action)
        {
          actions.add_action (action);
        }

      private new void add_action_ (string name, GLib.VariantType? parameter_type, owned GLib.SimpleActionActivateCallback callback)
        {
          GLib.SimpleAction action;
          (action = new GLib.SimpleAction (name, parameter_type)).activate.connect ((a, p) => callback (a, p));
          this.add_action (action);
        }

      public void change_action_state (string action_name, GLib.Variant value)
        {
          actions.change_action_state (action_name, value);
        }

      private unowned Gtk.EntryBuffer entrybuffer_from_name (string name)
        {
          int t;
          assert (name.substring (0, (t = "entrybuffer".length)) == "entrybuffer");

          switch (name [t])
            {
              case '1': return entrybuffer1;
              case '2': return entrybuffer2;
              case '3': return entrybuffer3;
              case '4': return entrybuffer4;
              default: assert_not_reached ();
            }
        }

		  public string[] list_actions ()
        {
          return actions.list_actions ();
        }

      public unowned GLib.Action? lookup_action (string action_name)
        {
          return actions.lookup_action (action_name);
        }

      private void pickfile_dialog (string name, bool saving)
        {
          var application = (Gtk.Application) GLib.Application.get_default ();
          var active_window = application?.active_window;
          var entrybuffer = entrybuffer_from_name (name);
          var picker = new Gtk.FileDialog ();

          picker.accept_label = _ ("Pick");
          picker.title = _ ("Pick a file ...");

          if (saving)

            picker.save.begin (active_window, null, (o, res) =>
              {
                try { entrybuffer.set_text (("file:" + (((Gtk.FileDialog) o).save.end (res)).get_path ()).data); } catch (GLib.Error e)
                  {
                    if (!(e.matches (Gtk.DialogError.quark (), Gtk.DialogError.CANCELLED) || e.matches (Gtk.DialogError.quark (), Gtk.DialogError.DISMISSED)))
                      {
                        ((Application) GLib.Application.get_default ()).notify_recoverable_error (e);
                        return;
                      }
                  }
              });
          else

            picker.open.begin (active_window, null, (o, res) =>
              {
                try { entrybuffer.set_text (("file:" + (((Gtk.FileDialog) o).open.end (res)).get_path ()).data); } catch (GLib.Error e)
                  {
                    if (!(e.matches (Gtk.DialogError.quark (), Gtk.DialogError.CANCELLED) || e.matches (Gtk.DialogError.quark (), Gtk.DialogError.DISMISSED)))
                      {
                        ((Application) GLib.Application.get_default ()).notify_recoverable_error (e);
                        return;
                      }
                  }
              });
        }

      public override bool query_action (string action_name, out bool enabled, out unowned GLib.VariantType parameter_type, out unowned GLib.VariantType state_type, out GLib.Variant state_hint, out GLib.Variant state)
        {
          return actions.query_action (action_name, out enabled, out parameter_type, out state_type, out state_hint, out state);
        }

      public void remove_action (string action_name)
        {
          actions.remove_action (action_name);
        }

      private void withtype_action (string name, string type)
        {
          entrybuffer_from_name (name).set_text (@"$type:".data);
        }

      [GtkCallback] public void on_button1_clicked (Gtk.Button button1)
        {
          close ();
        }

      [GtkCallback] public void on_button2_clicked (Gtk.Button button2)
        {
          externalize ();
        }

      [GtkCallback] public void on_button3_clicked (Gtk.Button button3)
        {
          RoleSource key_source;
          RoleTarget target_source;

          try { key_source = new RoleSource.parse (entrybuffer1.text); } catch (GLib.Error e)
            {
              ((Application) GLib.Application.get_default ()).notify_recoverable_error (e);
              return;
            }

          try { target_source = new RoleTarget.parse (entrybuffer2.text); } catch (GLib.Error e)
            {
              ((Application) GLib.Application.get_default ()).notify_recoverable_error (e);
              return;
            }

          target_source.show_output.connect (v => this.entrybuffer2.set_text (v.data));
          role.on_get (key_source, target_source);
        }

      [GtkCallback] public void on_button4_clicked (Gtk.Button button4)
        {
          RoleSource key_source, value_source;

          try { key_source = new RoleSource.parse (entrybuffer3.text); } catch (GLib.Error e)
            {
              ((Application) GLib.Application.get_default ()).notify_recoverable_error (e);
              return;
            }

          try { value_source = new RoleSource.parse (entrybuffer4.text); } catch (GLib.Error e)
            {
              ((Application) GLib.Application.get_default ()).notify_recoverable_error (e);
              return;
            }

          role.on_set (key_source, value_source);
        }
    }
}
