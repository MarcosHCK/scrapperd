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

  public class RoleRow : Gtk.Grid
    {
      [GtkChild] private unowned Gtk.Expander? expander1 = null;
      [GtkChild] private unowned Gtk.Label? label1 = null;

      public Role role { get; construct; }
      public bool expanded { get { return expander1.expanded; } set { expander1.expanded = value; } }

      public signal void close ();
      public signal void externalize ();

      construct
        {
          role.bind_property ("id", label1, "label", GLib.BindingFlags.SYNC_CREATE);
          role.bind_property ("role", expander1, "label", GLib.BindingFlags.SYNC_CREATE);
        }

      public RoleRow (Role role)
        {
          Object (role : role);
        }

      [GtkCallback] public void on_button1_clicked (Gtk.Button button1)
        {
          close ();
        }

      [GtkCallback] public void on_button2_clicked (Gtk.Button button2)
        {
          externalize ();
        }
    }
}
