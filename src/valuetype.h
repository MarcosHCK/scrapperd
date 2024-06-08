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
#ifndef __KADEMLIA_VALUETYPE__
#define __KADEMLIA_VALUETYPE__ 1
#include <glib-object.h>

typedef struct _KValue KValue;

#if __cplusplus
extern "C" {
#endif // __cplusplus

  KValue* k_value_copy (KValue* value);
  void k_value_free (KValue* value);

  static __inline GType k_value_get_type_once (void) G_GNUC_CONST;

  static __inline GType k_value_get_type_once (void)
    {
      static gsize g_type_id = 0;

      if (g_once_init_enter (&g_type_id))
        {
          GType g_type;

          g_type = g_boxed_type_register_static (g_intern_static_string ("KValue"), (GBoxedCopyFunc) k_value_copy, (GBoxedFreeFunc) k_value_free);
          g_once_init_leave (&g_type_id, (gsize) g_type);
        }
      return (GType) g_type_id;
    }

#if __cplusplus
}
#endif // __cplusplus

#endif // __KADEMLIA_VALUETYPE__
