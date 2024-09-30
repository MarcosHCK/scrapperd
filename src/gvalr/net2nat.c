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
#include <config.h>
#include <gvalr.h>

#define g_type_jge(a,b) (G_GNUC_EXTENSION ({ \
    GType __a = (a); \
    GType __b = (b); \
    (__a == __b || g_type_is_a (__a, __b)); \
  }))

static gpointer variant2boxed (GVariant* variant, GType gtype)
{
  if (g_type_jge (gtype, G_TYPE_BYTES))
    {
      gsize size;
      gconstpointer data = g_variant_get_fixed_array (variant, &size, sizeof (guint8));
      return g_bytes_new (data, size);
    }

  g_error ("unsupported boxed type %s", g_type_name (gtype));
}

void g_valr_net2nat (GValue* value, GVariant* variant)
{
  g_assert (g_variant_check_format_string (variant, "(sv)", FALSE));
  g_type_ensure (G_TYPE_BYTES);

  const gchar* ntype;
  const GType gtype = g_type_from_name (ntype = g_variant_get_string (g_variant_get_child_value (variant, 0), NULL));
  const GVariant* packed;
  const GVariantType* vtype = g_variant_get_type (packed = g_variant_get_variant (g_variant_get_child_value (variant, 1)));

  if (G_UNLIKELY (gtype == G_TYPE_NONE)) g_error ("unknown type %s", ntype);

  else switch (g_type_fundamental (gtype))
    {
      case G_TYPE_BOOLEAN: g_value_init (value, gtype); g_value_set_boolean (value, g_variant_get_boolean (packed)); break;
      case G_TYPE_BOXED: g_value_init (value, gtype); g_value_take_boxed (value, variant2boxed (packed, gtype)); break;
      case G_TYPE_CHAR: g_value_init (value, gtype); g_value_set_schar (value, (gint8) g_variant_get_byte (packed)); break;
      case G_TYPE_DOUBLE: g_value_init (value, gtype); g_value_set_double (value, g_variant_get_double (packed)); break;
      case G_TYPE_ENUM: g_value_init (value, gtype); g_value_set_enum (value, g_variant_get_int32 (packed)); break;
      case G_TYPE_FLAGS: g_value_init (value, gtype); g_value_set_flags (value, g_variant_get_uint32 (packed)); break;
      case G_TYPE_FLOAT: g_value_init (value, gtype); g_value_set_float (value, (gfloat) g_variant_get_double (packed)); break;
      case G_TYPE_INT: g_value_init (value, gtype); g_value_set_int (value, g_variant_get_int32 (packed)); break;
      case G_TYPE_INT64: g_value_init (value, gtype); g_value_set_int64 (value, g_variant_get_int64 (packed)); break;
    #if GLIB_SIZEOF_LONG == 8
      case G_TYPE_LONG: g_value_init (value, gtype); g_value_set_long (value, g_variant_get_int64 (packed)); break;
    #elif GLIB_SIZEOF_LONG == 4
      case G_TYPE_LONG: g_value_init (value, gtype); g_value_set_long (value, g_variant_get_int32 (packed)); break;
    #endif // GLIB_SIZEOF_LONG
      case G_TYPE_STRING: g_value_init (value, gtype); g_value_set_string (value, g_variant_get_string (packed, NULL)); break;
      case G_TYPE_UCHAR: g_value_init (value, gtype); g_value_set_uchar (value, g_variant_get_byte (packed)); break;
      case G_TYPE_UINT: g_value_init (value, gtype); g_value_set_uint (value, g_variant_get_uint32 (packed)); break;
      case G_TYPE_UINT64: g_value_init (value, gtype); g_value_set_uint64 (value, g_variant_get_uint64 (packed)); break;
    #if GLIB_SIZEOF_LONG == 8
      case G_TYPE_ULONG: g_value_init (value, gtype); g_value_set_ulong (value, g_variant_get_uint64 (packed)); break;
    #elif GLIB_SIZEOF_LONG == 4
      case G_TYPE_ULONG: g_value_init (value, gtype); g_value_set_ulong (value, g_variant_get_uint32 (packed)); break;
    #endif // GLIB_SIZEOF_LONG
      case G_TYPE_VARIANT: g_value_init (value, gtype); g_value_set_variant (value, g_variant_get_variant (packed)); break;
      default: g_error ("unsupported type %s", g_type_name (gtype));
    }
}
