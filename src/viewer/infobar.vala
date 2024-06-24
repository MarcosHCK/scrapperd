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
  [GtkTemplate (ui = "/org/hck/ScrapperD/Viewer/gtk/infobar.ui")]

  public class InfoBar : Gtk.Grid, Gtk.Buildable
    {
      [GtkChild] private unowned Gtk.Box? box1 = null;
      [GtkChild] private unowned Gtk.Revealer? revealer1 = null;
      public unowned InfoBarMessage? last = null;

      class construct
        {
          set_css_name ("infobar");
        }

      public void pop_all_messages ()
        {
          revealer1.reveal_child = false;
          steal_last (ref last);
        }

      public void pop_message ()
        {
          setup_next (last = steal_last (ref last)?.sibling);
          revealer1.reveal_child = last != null;
        }

      public void push_message (InfoBarMessage message)
        {
          message.sibling = steal_last (ref last);
          revealer1.reveal_child = true;
          setup_next (last = message);
        }

      private InfoBarMessage? setup_next (InfoBarMessage? next)
        {
          if (next != null)
            {
              box1.add_css_class (next.message_type.css_class ());
              box1.append (next);
              next.dismiss.connect (pop_message);
              next.dismiss_all.connect (pop_all_messages);
            }
          return next;
        }

      private InfoBarMessage? steal_last (ref unowned InfoBarMessage? last)
        {
          if (last == null) return null; else
            {
              var stolen = (InfoBarMessage) last;

              last = null;
              box1.remove (stolen);
              box1.remove_css_class (stolen.message_type.css_class ());
              stolen.dismiss.disconnect (pop_message);
              stolen.dismiss_all.disconnect (pop_all_messages);

              return stolen;
            }
        }

      public void push_error (string error)
        {
          push_message (new InfoBarMessage (error, InfoBarMessageType.ERROR));
        }

      public void push_info (string info)
        {
          push_message (new InfoBarMessage (info, InfoBarMessageType.INFO));
        }

      public void push_recoverable_error (GLib.Error error)
        {
          push_message (new InfoBarMessage.from_gerror (error, InfoBarMessageType.WARNING));
        }

      public void push_unrecoverable_error (GLib.Error error)
        {
          push_message (new InfoBarMessage.from_gerror (error, InfoBarMessageType.ERROR));
        }

      public void push_warning (string warning)
        {
          push_message (new InfoBarMessage (warning, InfoBarMessageType.WARNING));
        }
    }
}
