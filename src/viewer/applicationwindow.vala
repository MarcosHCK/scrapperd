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
  [GtkTemplate (ui = "/org/hck/ScrapperD/Viewer/gtk/applicationwindow.ui")]

  public class ApplicationWindow : Gtk.ApplicationWindow
    {
      [GtkChild] private unowned Gtk.ListBox? listbox1 = null;
      [GtkChild] private unowned Gtk.MenuButton? menubutton1 = null;
      [GtkChild] private unowned InfoBar? infobar1 = null;
      private HashTable<unowned Gtk.Widget, unowned Gtk.ListBoxRow> rows;

      public InfoBar infobar { get { return infobar1; } }

      construct
        {
          unowned var key_equal_func = GLib.str_equal;
          unowned var hash_func = GLib.str_hash;

          notify ["application"].connect (reset_menu);
          rows = new HashTable<unowned Gtk.Widget, unowned Gtk.ListBoxRow> (hash_func, key_equal_func);
        }

      public ApplicationWindow (Gtk.Application application)
        {
          Object (application : application);
        }

      public void append_row (Gtk.Widget child) requires (child is Gtk.ListBoxRow == false)
        {
          var row = new Gtk.ListBoxRow ();

          row.set_child (child);
          rows.insert (child, row);
          listbox1.append (row);
        }

      public void remove_row (Gtk.Widget child) requires (child is Gtk.ListBoxRow == false)
        {
          Gtk.ListBoxRow? row;

          if ((row = rows.lookup (child)) != null)

            listbox1.remove (row);
        }

      private static void reset_menu (GLib.Object? _sender, GLib.ParamSpec pspec)
        {
          var self = (ApplicationWindow) _sender;
          var menu_model = self.application.get_menu_by_id ("menubar");
          var menu_button = self.menubutton1;
          menu_button.menu_model = menu_model;
        }
    }
}
