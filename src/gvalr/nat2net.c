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

static GVariant* boxed2variant (gpointer box, GType gtype)
{
  if (g_type_jge (gtype, G_TYPE_BYTES))

    return g_variant_new_from_bytes (G_VARIANT_TYPE_BYTESTRING, box, FALSE);

  g_error ("unsupported boxed value %s", g_type_name (gtype));
}

GVariant* g_valr_nat2net (GValue* value)
{
  GVariantBuilder builder = G_VARIANT_BUILDER_INIT ("(sv)");

  if (G_VALUE_HOLDS_POINTER (value) && g_value_get_pointer (value) == NULL)
    {
      g_variant_builder_add_value (&builder, g_variant_new_string (g_type_name (G_TYPE_NONE)));
      g_variant_builder_add_value (&builder, g_variant_new_variant (g_variant_new_maybe (NULL, NULL)));
    }
  else
    {
      g_variant_builder_add_value (&builder, g_variant_new_string (G_VALUE_TYPE_NAME (value)));

      switch (g_type_fundamental (G_VALUE_TYPE (value)))
        {
          case G_TYPE_BOOLEAN: g_variant_builder_add (&builder, "v", g_variant_new_boolean (g_value_get_boolean (value))); break;
          case G_TYPE_BOXED: g_variant_builder_add (&builder, "v", boxed2variant (g_value_get_boxed (value), G_VALUE_TYPE (value))); break;
          case G_TYPE_CHAR: g_variant_builder_add (&builder, "v", g_variant_new_byte ((guint8) g_value_get_schar (value))); break;
          case G_TYPE_DOUBLE: g_variant_builder_add (&builder, "v", g_variant_new_double (g_value_get_double (value))); break;
          case G_TYPE_ENUM: g_variant_builder_add (&builder, "v", g_variant_new_int32 (g_value_get_enum (value))); break;
          case G_TYPE_FLAGS: g_variant_builder_add (&builder, "v", g_variant_new_uint32 (g_value_get_flags (value))); break;
          case G_TYPE_FLOAT: g_variant_builder_add (&builder, "v", g_variant_new_double ((gdouble) g_value_get_float (value))); break;
          case G_TYPE_INT: g_variant_builder_add (&builder, "v", g_variant_new_int32 (g_value_get_int (value))); break;
          case G_TYPE_INT64: g_variant_builder_add (&builder, "v", g_variant_new_int64 (g_value_get_int64 (value))); break;
        #if GLIB_SIZEOF_LONG == 8
          case G_TYPE_LONG: g_variant_builder_add (&builder, "v", g_variant_new_int64 (g_value_get_long (value))); break;
        #elif GLIB_SIZEOF_LONG == 4
          case G_TYPE_LONG: g_variant_builder_add (&builder, "v", g_variant_new_int32 (g_value_get_long (value))); break;
        #endif // GLIB_SIZEOF_LONG
          case G_TYPE_STRING: g_variant_builder_add (&builder, "v", g_variant_new_string (g_value_get_string (value))); break;
          case G_TYPE_UCHAR: g_variant_builder_add (&builder, "v", g_variant_new_byte (g_value_get_uchar (value))); break;
          case G_TYPE_UINT: g_variant_builder_add (&builder, "v", g_variant_new_uint32 (g_value_get_uint (value))); break;
          case G_TYPE_UINT64: g_variant_builder_add (&builder, "v", g_variant_new_uint64 (g_value_get_uint64 (value))); break;
        #if GLIB_SIZEOF_LONG == 8
          case G_TYPE_ULONG: g_variant_builder_add (&builder, "v", g_variant_new_uint64 (g_value_get_ulong (value))); break;
        #elif GLIB_SIZEOF_LONG == 4
          case G_TYPE_ULONG: g_variant_builder_add (&builder, "v", g_variant_new_uint32 (g_value_get_ulong (value))); break;
        #endif // GLIB_SIZEOF_LONG
          case G_TYPE_VARIANT: g_variant_builder_add (&builder, "v", g_variant_new_variant (g_value_get_variant (value))); break;
          default: g_error ("unsupported value %s", G_VALUE_TYPE_NAME (value)); break;
        }
    }

  return g_variant_builder_end (&builder);
}
