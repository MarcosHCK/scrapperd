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
  [GtkTemplate (ui = "/org/hck/ScrapperD/Viewer/gtk/joindialog.ui")]

  public class JoinDialog : Gtk.Window
    {
      [GtkChild] private unowned Gtk.Button? button1 = null;
      [GtkChild] private unowned Gtk.Entry? entry1 = null;
      [GtkChild] private unowned Gtk.EntryBuffer? entrybuffer1 = null;

      private WeakRef _action_target;
      public string action_name { get; set; }
      public ActionMap action_target { owned get { return (ActionMap) _action_target.get (); } set { _action_target.set (value); } }
      public string expecting { set { entry1.placeholder_text = value; } }

      construct
        {
          accessible_role = Gtk.AccessibleRole.DIALOG;

          button1.clicked.connect (() => on_button1_activate ());
        }

      public JoinDialog (Gtk.Application application)
        {
          Object (application : application);
        }

      private void on_button1_activate ()
        {
          var address = (string) entrybuffer1.text;
          var action = (Action?) action_target?.lookup_action (action_name);

          close ();
          action?.activate (new GLib.Variant.take_string ((owned) address));
        }
    }
}
