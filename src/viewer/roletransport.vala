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
  public errordomain RoleTransportError
    {
      FAILED,
      INVALID,
      UNKNOWN_TYPE;

      public static extern GLib.Quark quark ();
    }

  public abstract class RoleTransport
    {

      protected static void parse<T> (string value, T default_, out string source, out T type) throws GLib.Error
        {
          string[] bits;

          if ((bits = value.split (":", 2)).length == 0)
            {
              throw new RoleTransportError.INVALID ("invalid empty transport");
            }
          else if (bits.length == 1)
            {
              source = value;
              type = (T) default_;
            }
          else
            {
              var enum_class = (EnumClass?) typeof (T).class_ref ();
              var enum_value = (EnumValue?) enum_class.get_value_by_nick (bits [0]);

              if (enum_value == null)

                throw new RoleTransportError.UNKNOWN_TYPE ("unknown transport type '%s'", bits [0]);
              else
                {
                  source = bits [1];
                  type = (T) enum_value.value;
                }
            }
        }
    }
}
