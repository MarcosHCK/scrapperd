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
  [CCode (array_length_pos = 1.1, array_length_type = "gsize", cheader_filename = "glib.h", cname = "g_variant_get_fixed_array", simple_generics = true)]

  static extern unowned T[] _g_variant_get_fixed_array<T> (GLib.Variant variant, size_t element_size = sizeof (T));

  public static GLib.Value? net2nat (GLib.Variant variant)
    {
      GLib.Value? value = null;

      typeof (GLib.Bytes).ensure ();

      if (unlikely (variant.check_format_string ("(sv)", false) == false))

        error ("invalid variant type '%s'", variant.get_type_string ());

      var good = true;
      var packed = (GLib.Variant?) null;
      unowned var type_name = (string?) null;
      unowned var gtype = GLib.Type.from_name (type_name = variant.get_child_value (0).get_string ());
      unowned var vtype = (packed = variant.get_child_value (1).get_variant ())?.get_type ();

      if (unlikely (gtype == (GLib.Type) 0))

        error ("invalid type '%s'", type_name);

      switch (_fundamental_type (gtype))
        {
          case GLib.Type.BOOLEAN: (value = GLib.Value (gtype)).set_boolean (packed.get_boolean ()); break;
          case GLib.Type.CHAR: (value = GLib.Value (gtype)).set_schar ((int8) packed.get_byte ()); break;
          case GLib.Type.DOUBLE: (value = GLib.Value (gtype)).set_double (packed.get_double ()); break;
          case GLib.Type.ENUM: (value = GLib.Value (gtype)).set_enum (packed.get_int32 ()); break;
          case GLib.Type.FLAGS: (value = GLib.Value (gtype)).set_flags (packed.get_int32 ()); break;
          case GLib.Type.FLOAT: (value = GLib.Value (gtype)).set_float ((float) packed.get_double ()); break;
          case GLib.Type.INT: (value = GLib.Value (gtype)).set_int ((int) packed.get_int32 ()); break;
          case GLib.Type.INT64: (value = GLib.Value (gtype)).set_int64 (packed.get_int64 ()); break;
          case GLib.Type.LONG: (value = GLib.Value (gtype)).set_long ((long) packed.get_int64 ()); break;
          case GLib.Type.NONE: return null;
          case GLib.Type.STRING: (value = GLib.Value (gtype)).set_string (packed.get_string ()); break;
          case GLib.Type.UCHAR: (value = GLib.Value (gtype)).set_uchar (packed.get_byte ()); break;
          case GLib.Type.UINT: (value = GLib.Value (gtype)).set_uint ((uint) packed.get_uint32 ()); break;
          case GLib.Type.UINT64: (value = GLib.Value (gtype)).set_uint64 ((uint64) packed.get_uint64 ()); break;
          case GLib.Type.ULONG: (value = GLib.Value (gtype)).set_ulong ((ulong) packed.get_uint64 ()); break;
          case GLib.Type.VARIANT: (value = GLib.Value (gtype)).set_variant (packed.get_variant ()); break;

          case GLib.Type.BOXED:

            if (is_a_or_equal (gtype, typeof (GLib.Bytes)))
              {
                (value = GLib.Value (gtype)).set_boxed (new GLib.Bytes (_g_variant_get_fixed_array (packed)));
              }
            else
              {
                good = false;
              }
            break;

          default: good = false; break;
        }

      if (unlikely (good == false))
        {
          error ("invalid packed variant type '%s'", vtype.dup_string ());
        }

      return (owned) value;
    }
}
