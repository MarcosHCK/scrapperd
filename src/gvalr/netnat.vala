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

[CCode (cprefix = "GValr", lower_case_cprefix = "g_valr_")]

namespace GValr
{
  [CCode (cheader_filename = "glib-object.h", cname = "G_TYPE_FUNDAMENTAL")]

  internal static extern GLib.Type _fundamental_type (GLib.Type g_type);

  internal static bool is_a_or_equal (GLib.Type gtype, GLib.Type a_or_equal)
    {
      return gtype == a_or_equal || gtype.is_a (a_or_equal);
    }
}
