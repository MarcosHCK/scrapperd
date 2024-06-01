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
#ifndef __K_VALUE__
#define __K_VALUE__ 1
#include <glib-object.h>
#include <key.h>

#define K_TYPE_VALUE (k_value_get_type ())
typedef struct _KValue KValue;

#if __cplusplus
extern "C" {
#endif // __cplusplus

  struct _KValue
    {
      guint n_neighbors;

      union
      {
        KKey** neighbors;
        GBytes* inmediate;
      };
    };

  GType k_value_get_type (void) G_GNUC_CONST;

  KValue* k_value_copy (KValue* value);
  void k_value_free (KValue* value);
  KValue* k_value_new_delegated (KKey** keys, guint n_keys);
  KValue* k_value_new_inmediate (GBytes* bytes);

  #define k_value_is_delegated(value) ((value)->n_neighbors > 0)
  #define k_value_is_inmediate(value) ((value)->n_neighbors == 0)

#if __cplusplus
}
#endif // __cplusplus

#endif // __K_VALUE__
