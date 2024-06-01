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
#ifndef __K_KEY__
#define __K_KEY__ 1
#include <glib-object.h>

#define K_TYPE_KEY (k_key_get_type ())
typedef struct _KKey KKey;

#define K_KEY_BITLEN 160

#if __cplusplus
extern "C" {
#endif // __cplusplus

  GType k_key_get_type (void) G_GNUC_CONST;

  KKey* k_key_copy (KKey* key);
  gboolean k_key_equal (KKey* keya, KKey* keyb) G_GNUC_PURE;
  KKey* k_key_distance (KKey* keya, KKey* keyb) G_GNUC_PURE;
  void k_key_free (KKey* key);
  guint k_key_hash (KKey* key) G_GNUC_PURE;
  const guint8* k_key_get_bytes (KKey* key);
  KKey* k_key_new_from_bytes (GBytes* bytes);
  KKey* k_key_new_from_data (gconstpointer data, gsize size);
  KKey* k_key_new_random (void);
  gchar* k_key_to_string (KKey* key);

  #define k_key_nth_bit(key,nth) (G_GNUC_EXTENSION ({ \
 ; \
      const KKey* __key = (key); \
      const gint __nth_ = (nth); \
      const guint __nth = __nth_ >= 0 ? __nth_ : K_KEY_BITLEN + __nth_; \
      (k_key_get_bytes ((KKey*) __key) [__nth >> 3] >> (__nth & 3)) & 1; \
    }))

  #define k_key_tmp(bytes) ((KKey*) ((bytes)))

  typedef GChecksum KKeyBuilder;

  KKey* k_key_builder_end (KKeyBuilder* builder);
  KKeyBuilder* k_key_builder_new (void);

  #define k_key_builder_update g_checksum_update
  #define k_key_builder_free g_checksum_free

#if __cplusplus
}
#endif // __cplusplus

#endif // __K_KEY__
