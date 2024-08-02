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
  [GtkTemplate (ui = "/org/hck/ScrapperD/Viewer/gtk/adrow.ui")]

  public class AdRow : Gtk.Grid, GLib.ActionGroup, GLib.ActionMap
    {
      [GtkChild] private unowned Gtk.Label? label1 = null;
      [GtkChild] private unowned Gtk.Label? label2 = null;
      public Kademlia.Ad.Protocol proto { get; construct; }
      private GLib.SimpleActionGroup actions;

      public Kademlia.Key id { owned get { return parse_id (label2.label); } set { label2.label = value.to_string (); } }
      public string role { get { return label1.label; } set { label1.label = value; } }

      public signal void close ();
      public signal void externalize ();
      public signal void join ();

      construct
        {
          insert_action_group ("row", actions = new GLib.SimpleActionGroup ());

          proto.bind_property ("id", this, "id", GLib.BindingFlags.SYNC_CREATE);
          proto.bind_property ("role", this, "role", GLib.BindingFlags.SYNC_CREATE);
        }

      public AdRow (Kademlia.Ad.Protocol proto)
        {
          Object (proto : proto);
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

      public void change_action_state (string action_name, GLib.Variant value)
        {
          actions.change_action_state (action_name, value);
        }

      public string[] list_actions ()
        {
          return actions.list_actions ();
        }

      public unowned GLib.Action? lookup_action (string action_name)
        {
          return actions.lookup_action (action_name);
        }

      private Kademlia.Key parse_id (string id_str)
        {
          try { return new Kademlia.Key.parse (id_str); } catch (GLib.Error e)
            {
              unowned var code = e.code;
              unowned var domain = e.domain.to_string ();
              unowned var message = e.message.to_string ();
              e = null;

              error ("%s: %i: %s", domain, code, message);
            }
        }

      public override bool query_action (string action_name, out bool enabled, out unowned GLib.VariantType parameter_type, out unowned GLib.VariantType state_type, out GLib.Variant state_hint, out GLib.Variant state)
        {
          return actions.query_action (action_name, out enabled, out parameter_type, out state_type, out state_hint, out state);
        }

      public void remove_action (string action_name)
        {
          actions.remove_action (action_name);
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
          join ();
        }
    }
}
