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
  public enum InfoBarMessageType
    {
      ERROR,
      INFO,
      WARNING;

      internal string css_class ()
        {
          var type_class = (GLib.EnumClass?) typeof (InfoBarMessageType).class_ref ();
          var type_value = (GLib.EnumValue?) type_class.get_value ((int) this);
          assert (type_value != null);
          return type_value.value_nick;
        }
    }

  [GtkTemplate (ui = "/org/hck/ScrapperD/Viewer/gtk/infobarmessage.ui")]

  public class InfoBarMessage : Gtk.Grid, Gtk.Buildable
    {
      [GtkChild] private unowned Gtk.Label? label1 = null;

      public string message { get { return label1.label; } construct { label1.label = value; } }
      public InfoBarMessageType message_type { get; construct; }

      internal InfoBarMessage? sibling { get; set; }

      public signal void dismiss ();
      public signal void dismiss_all ();

      class construct
        {
          set_css_name ("infobarmessage");
        }

      public InfoBarMessage (string message, InfoBarMessageType type)
        {
          Object (message : message, message_type : type);
        }

      public InfoBarMessage.from_gerror (GLib.Error? error, InfoBarMessageType type = InfoBarMessageType.ERROR)
        {
          Object (message : @"$(error.domain): $(error.code): $(error.message)", message_type : type);
        }

      [GtkCallback] public void on_button1_clicked (Gtk.Button button1)
        {
          dismiss ();
        }
    }
}
