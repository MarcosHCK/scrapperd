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

[CCode (cprefix = "Scrapping", lower_case_cprefix = "scrapping_")]

namespace Scrapping
{
  [CCode (cheader_filename = "validuri.h", cname = "_g_uri_is_valid")]

  public static extern bool uri_is_valid (GLib.Uri uri);

  public static GLib.Uri normal_uri (string uri_string) throws GLib.UriError
    {
      var flags1 = GLib.UriFlags.ENCODED;
      var flags2 = GLib.UriFlags.SCHEME_NORMALIZE;
      var flags = flags1 | flags2;
      return Uri.parse (uri_string, flags);
    }

  public static GLib.Uri normalize_uri (GLib.Uri uri)
    {
      var flags1 = GLib.UriHideFlags.AUTH_PARAMS;
      var flags2 = GLib.UriHideFlags.FRAGMENT;
      var flags3 = GLib.UriHideFlags.PASSWORD;
      var flags4 = GLib.UriHideFlags.USERINFO;
      var flags = flags1 | flags2 | flags3 | flags4;
      var uri_string = uri.to_string_partial (flags);

      try { return Uri.parse (uri_string, GLib.UriFlags.ENCODED); } catch (GLib.Error e)
        {
          error (@"$(e.domain): $(e.code): $(e.message)");
        }
    }
}
