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

      internal static GLib.Variant nat2net (GLib.Value? value)
        {
          var vtype = new GLib.VariantType ("(sv)");
          var builder = new GLib.VariantBuilder (vtype);
          var good = true;

          builder.add ("s", value.type_name ());

          switch (_fundamental_type (value.type ()))
            {
              case GLib.Type.BOOLEAN: builder.add ("v", new GLib.Variant.boolean (value.get_boolean ())); break;
              case GLib.Type.CHAR: builder.add ("v", new GLib.Variant.byte (value.get_schar ())); break;
              case GLib.Type.DOUBLE: builder.add ("v", new GLib.Variant.double (value.get_double ())); break;
              case GLib.Type.ENUM: builder.add ("v", new GLib.Variant.int32 (value.get_int ())); break;
              case GLib.Type.FLAGS: builder.add ("v", new GLib.Variant.int32 (value.get_int ())); break;
              case GLib.Type.FLOAT: builder.add ("v", new GLib.Variant.double (value.get_float ())); break;
              case GLib.Type.INT: builder.add ("v", new GLib.Variant.int32 (value.get_int ())); break;
              case GLib.Type.INT64: builder.add ("v", new GLib.Variant.int64 (value.get_int64 ())); break;
              case GLib.Type.LONG: builder.add ("v", new GLib.Variant.int64 (value.get_long ())); break;
              case GLib.Type.STRING: builder.add ("v", new GLib.Variant.string (value.get_string ())); break;
              case GLib.Type.UCHAR: builder.add ("v", new GLib.Variant.byte (value.get_uchar ())); break;
              case GLib.Type.UINT: builder.add ("v", new GLib.Variant.uint32 (value.get_uint ())); break;
              case GLib.Type.UINT64: builder.add ("v", new GLib.Variant.uint64 (value.get_uint64 ())); break;
              case GLib.Type.ULONG: builder.add ("v", new GLib.Variant.uint64 (value.get_ulong ())); break;
              case GLib.Type.VARIANT: builder.add ("v", new GLib.Variant.variant (value.get_variant ())); break;

              case GLib.Type.BOXED:

                if (value.holds (typeof (GLib.Bytes)))
                  {
                    unowned var vtype_ = GLib.VariantType.BYTESTRING;
                    builder.add ("v", new GLib.Variant.from_bytes (vtype_, (Bytes) value.get_boxed (), false));
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

          return builder.end ();
        }

      internal static GLib.Value? net2nat (GLib.Variant variant)
        {
          if (unlikely (variant.check_format_string ("(sv)", false) == false))

            error ("invalid variant type '%s'", variant.get_type_string ());

          var packed = (GLib.Variant?) null;
          unowned var type_name = (string?) null;
          unowned var gtype = GLib.Type.from_name (type_name = variant.get_child_value (0).get_string ());
          unowned var vtype = (packed = variant.get_child_value (1).get_variant ()).get_type ();

          if (unlikely (gtype == (GLib.Type) 0))

            error ("invalid type '%s'", type_name);

          var good = true;
          var value = GLib.Value (gtype);

          if (vtype.is_basic () == false)
            {
              if (unlikely (vtype.is_array () == false || vtype.element ().equal (GLib.VariantType.BYTE) == false))
                {
                  value.set_boxed (new GLib.Bytes (packed.get_bytestring ().data));
                }
            }
          else switch ((string) vtype.peek_string ())
            {
              case "b": if (unlikely ((good = value.holds (typeof (bool))) == false))
                  {
                    value.set_boolean (packed.get_boolean ());
                  }
                break;
              case "d": switch (_fundamental_type (gtype))
                  {
                    case GLib.Type.DOUBLE: value.set_double (packed.get_double ()); break;
                    case GLib.Type.FLOAT: value.set_float ((float) packed.get_double ()); break;
                    default: good = false; break;
                  }
                break;
              case "i": switch (_fundamental_type (gtype))
                  {
                    case GLib.Type.ENUM: value.set_enum (packed.get_int32 ()); break;
                    case GLib.Type.FLAGS: value.set_flags (packed.get_int32 ()); break;
                    case GLib.Type.INT: value.set_int (packed.get_int32 ()); break;
                    default: good = false; break;
                  }
                break;
              case "s": if (unlikely ((good = value.holds (typeof (string))) == false))
                  {
                    value.set_string (packed.get_string ());
                  }
                break;
              case "t": switch (_fundamental_type (gtype))
                  {
                    case GLib.Type.UINT64: value.set_uint64 (packed.get_uint64 ()); break;
                    case GLib.Type.ULONG: value.set_ulong ((ulong) packed.get_uint64 ()); break;
                    default: good = false; break;
                  }
                break;
              case "u": switch (_fundamental_type (gtype))
                  {
                    case GLib.Type.UINT: value.set_uint (packed.get_uint32 ()); break;
                    default: good = false; break;
                  }
                break;
              case "x": switch (_fundamental_type (gtype))
                  {
                    case GLib.Type.INT64: value.set_int64 (packed.get_int64 ()); break;
                    case GLib.Type.LONG: value.set_long ((long) packed.get_int64 ()); break;
                    default: good = false; break;
                  }
                break;
              case "y": switch (_fundamental_type (gtype))
                  {
                    case GLib.Type.CHAR: value.set_schar ((int8) packed.get_byte ()); break;
                    case GLib.Type.UCHAR: value.set_uchar (packed.get_byte ()); break;
                    default: good = false; break;
                  }
                break;
              default: good = false; break;
            }

          if (unlikely (good == false))
            {
              error ("invalid packed variant type '%s'", vtype.dup_string ());
            }

          return value;
        }
    }
}
