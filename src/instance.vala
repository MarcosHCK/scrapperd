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

[CCode (cprefix = "Scrapperd", lower_case_cprefix = "scrapperd_")]

namespace ScrapperD
{
  public abstract class Instance : GLib.Object
    {
      public const string EXTENSION_POINT = "org.hck.ScrapperD.Instance";

      private class List<GLib.OptionEntry?> option_entries = new List<GLib.OptionEntry?> ();

      [CCode (simple_generics = false)]
      public static void install<T> (string @as)
        {
          var gtype = typeof (T);
          GLib.IOExtensionPoint.implement (EXTENSION_POINT, gtype, @as, 0);
        }

      public class unowned List<GLib.OptionEntry?> get_option_entries ()
        {
          return option_entries;
        }

      protected class void add_option_entry (string long_name, char short_name, GLib.OptionFlags flags, GLib.OptionArg arg, string description, string? arg_description)
        {
          var entry = GLib.OptionEntry ();

          entry.arg = arg;
          entry.arg_data = null;
          entry.arg_description = arg_description;
          entry.description = description;
          entry.flags = flags;
          entry.long_name = long_name;
          entry.short_name = short_name;
          option_entries.prepend (entry);
        }
    }
}
