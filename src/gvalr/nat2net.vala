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
  public static GLib.Variant nat2net (GLib.Value? value)
    {
      var vtype = new GLib.VariantType ("(sv)");
      var builder = new GLib.VariantBuilder (vtype);
      var good = true;

      if (value == null)
        {
          builder.add_value (new Variant.string (GLib.Type.NONE.name ()));
          builder.add_value (new Variant.variant (new Variant.maybe (null, null)));
        }
      else
        {
          builder.add_value (new Variant.string (value.type_name ()));

          switch (_fundamental_type (value.type ()))
            {
              case GLib.Type.BOOLEAN: builder.add_value (new Variant.variant (new Variant.boolean (value.get_boolean ()))); break;
              case GLib.Type.CHAR: builder.add_value (new Variant.variant (new Variant.byte (value.get_schar ()))); break;
              case GLib.Type.DOUBLE: builder.add_value (new Variant.variant (new Variant.double (value.get_double ()))); break;
              case GLib.Type.ENUM: builder.add_value (new Variant.variant (new Variant.int32 (value.get_int ()))); break;
              case GLib.Type.FLAGS: builder.add_value (new Variant.variant (new Variant.int32 (value.get_int ()))); break;
              case GLib.Type.FLOAT: builder.add_value (new Variant.variant (new Variant.double (value.get_float ()))); break;
              case GLib.Type.INT: builder.add_value (new Variant.variant (new Variant.int32 (value.get_int ()))); break;
              case GLib.Type.INT64: builder.add_value (new Variant.variant (new Variant.int64 (value.get_int64 ()))); break;
              case GLib.Type.LONG: builder.add_value (new Variant.variant (new Variant.int64 (value.get_long ()))); break;
              case GLib.Type.STRING: builder.add_value (new Variant.variant (new Variant.string (value.get_string ()))); break;
              case GLib.Type.UCHAR: builder.add_value (new Variant.variant (new Variant.byte (value.get_uchar ()))); break;
              case GLib.Type.UINT: builder.add_value (new Variant.variant (new Variant.uint32 (value.get_uint ()))); break;
              case GLib.Type.UINT64: builder.add_value (new Variant.variant (new Variant.uint64 (value.get_uint64 ()))); break;
              case GLib.Type.ULONG: builder.add_value (new Variant.variant (new Variant.uint64 (value.get_ulong ()))); break;
              case GLib.Type.VARIANT: builder.add_value (new Variant.variant (new Variant.variant (value.get_variant ()))); break;

              case GLib.Type.BOXED:

                if ((good = is_a_or_equal (value.type (), typeof (GLib.Bytes))) == true)
                  {
                    var bytes_ = (Bytes) value.dup_boxed (); 
                    var vtype_ = new VariantType ("ay");

                    builder.add_value (new Variant.variant (new Variant.from_bytes (vtype_, bytes_, false)));
                  }

                break;

              default: good = false; break;
            }

          if (unlikely (good == false))
            {
              error ("unsupported type '%s'", value.type_name ());
            }
        }

      return builder.end ();
    }
}
