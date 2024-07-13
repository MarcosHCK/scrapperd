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

[CCode (cprefix = "KDBus", lower_case_cprefix = "k_dbus_")]

namespace Kademlia.DBus
{
  public struct Address
    {
      public string address;
      public uint16 port;

      public Address (owned string address, uint16 port)
        {
          this.address = (owned) address;
          this.port = port;
        }

      public static bool equal (Address? a, Address? b)
        {
          return a.port == b.port && GLib.str_equal (a.address, b.address);
        }

      public static uint hash (Address? a)
        {
          int a_ = a.port;
          return GLib.int_hash (a_) ^ GLib.str_hash (a.address);
        }
    }

  public struct KeyRef
    {
      public uint8[] value;

      public KeyRef (owned uint8[] value)
        {
          this.value = (owned) value;
        }
    }

  public struct PeerRef
    {
      Address[]? addresses;
      KeyRef? id;
      bool knowable;

      public PeerRef (owned uint8[] id, owned Address[] addresses)
        {
          this.addresses = (owned) addresses;
          this.id = KeyRef ((owned) id);
          this.knowable = true;
        }

      public PeerRef.anonymous (owned uint8[] id)
        {
          this.id = KeyRef ((owned) id);
          this.knowable = false;
        }

      internal Key? know (Hub hub)
        {
          Key? id = null;

          if (knowable)
            {
              id = new Key.verbatim (this.id.value);
              hub.add_contact_addresses (id, addresses);
            }
          return (owned) id;
        }
    }

  public struct ValueRef
    {
      bool found;
      PeerRef[]? others;
      Variant? value;

      public ValueRef.delegated (owned PeerRef[] others)
        {
          this.found = false;
          this.others = (owned) others;
          this.value = new Variant.byte (0);
        }

      public ValueRef.inmediate (owned GLib.Value? value)
        {
          this.found = true;
          this.value = nat2net (value);
        }

      public GLib.Value? get_value ()
        {
          return net2nat (value);
        }

      [CCode (cheader_filename = "glib-object.h", cname = "G_TYPE_FUNDAMENTAL")]

      static extern GLib.Type _fundamental_type (GLib.Type g_type);

      static bool is_a_or_equal (GLib.Type gtype, GLib.Type a_or_equal)
        {
          return gtype == a_or_equal || gtype.is_a (a_or_equal);
        }

      internal static GLib.Variant nat2net (GLib.Value? value)
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

                    if (is_a_or_equal (value.type (), typeof (GLib.Bytes)))
                      {
                        var bytes_ = (Bytes) value.dup_boxed (); 
                        var vtype_ = new VariantType ("ay");

                        builder.add_value (new Variant.variant (new Variant.from_bytes (vtype_, bytes_, false)));
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
                  error ("unsupported type '%s'", value.type_name ());
                }
            }

          return builder.end ();
        }

      [CCode (array_length_pos = 1.1, array_length_type = "gsize", cheader_filename = "glib.h", cname = "g_variant_get_fixed_array", simple_generics = true)]

      static extern unowned T[] _g_variant_get_fixed_array<T> (GLib.Variant variant, size_t element_size = sizeof (T));

      internal static GLib.Value? net2nat (GLib.Variant variant)
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
}
