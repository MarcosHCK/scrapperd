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
#include <key.h>

struct _KKey
{
  union
  {
    guint8 bytes [K_KEY_BITLEN >> 3];
    guint16 shorts [K_KEY_BITLEN >> 4];
    guint32 longs [K_KEY_BITLEN >> 5];
# if GLIB_SIZEOF_VOID_P >= 8
    guint64 quads [K_KEY_BITLEN >> 6];
# endif // GLIB_SIZEOF_VOID_P
  };
};

#define k_key_new() (g_slice_new (KKey))
#define CHECKSUM G_CHECKSUM_SHA1

G_STATIC_ASSERT ((K_KEY_BITLEN & 0x3) == 0);
G_DEFINE_BOXED_TYPE (KKey, k_key, k_key_copy, k_key_free)

KKey* k_key_builder_end (KKeyBuilder* builder)
{
  g_return_val_if_fail (builder != NULL, NULL);
  KKey* key;
  gsize size = K_KEY_BITLEN >> 3;

  g_checksum_get_digest (builder, (key = k_key_new ())->bytes, &size);
  return key;
}

KKeyBuilder* k_key_builder_new ()
{
  g_assert (g_checksum_type_get_length (CHECKSUM) == (K_KEY_BITLEN >> 3));
  return g_checksum_new (CHECKSUM);
}

KKey* k_key_copy (KKey* key)
{
  g_return_val_if_fail (key != NULL, NULL);
  return g_slice_dup (KKey, key);
}

gboolean k_key_equal (KKey* keya, KKey* keyb)
{
  return 0 == memcmp (keya->bytes, keyb->bytes, K_KEY_BITLEN >> 3);
}

KKey* k_key_distance (KKey* keya, KKey* keyb)
{
  g_return_val_if_fail (keya != NULL, NULL);
  g_return_val_if_fail (keyb != NULL, NULL);
  KKey* key = k_key_new ();
  guint i;

# if GLIB_SIZEOF_VOID_P >= 8
  /* 64 bits computer */
  for (i = 0; i < (K_KEY_BITLEN >> 6); ++i)
    key->quads [i] = keya->quads [i] ^ keya->quads [i];
  const int first = G_SIZEOF_MEMBER (KKey, quads);
# else // GLIB_SIZEOF_VOID_P < 8
  /* 32 bits computer */
  for (i = 0; i < (K_KEY_BITLEN >> 5); ++i)
    key->longs [i] = keya->longs [i] ^ keyb->longs [i];
  const int first = G_SIZEOF_MEMBER (KKey, longs);
# endif // GLIB_SIZEOF_VOID_P

  for (i = first; i < (K_KEY_BITLEN >> 3); ++i)
    {
      key->bytes [i] = keya->bytes [i] ^ keyb->bytes [i];
    }
  return key;
}

void k_key_free (KKey* key)
{
  if (key != NULL) g_slice_free (KKey, key);
}

guint k_key_hash (KKey* key)
{
  guint8* chars = key->bytes;
  guint i, hash;

  for (i = 0, hash = 5381; i < (K_KEY_BITLEN >> 3); ++i)
    {
      hash = hash * 33 + chars [i];
    }
  return hash;
}

const guint8* k_key_get_bytes (KKey* key)
{
  g_return_val_if_fail (key != NULL, NULL);
  return key->bytes;
}

KKey* k_key_new_from_bytes (GBytes* bytes)
{
  g_return_val_if_fail (bytes != NULL, NULL);
  KKeyBuilder* builder;

  gsize size;
  gconstpointer data = g_bytes_get_data (bytes, &size);

  k_key_builder_update (builder = k_key_builder_new (), data, size);

  return k_key_builder_end (builder);
}

KKey* k_key_new_from_data (gconstpointer data, gsize size)
{
  g_return_val_if_fail (data != NULL, NULL);
  g_return_val_if_fail (size < G_MAXSSIZE, NULL);
  KKeyBuilder* builder;

  k_key_builder_update (builder = k_key_builder_new (), data, size);

  return k_key_builder_end (builder);
}

KKey* k_key_new_random ()
{
  GRand* rand;
  KKey* key;
  gint64 time;
  guint i;

  time = g_get_monotonic_time ();
  rand = g_rand_new_with_seed_array ((guint32*) & time, sizeof (gint64) / sizeof (guint32));
  key = k_key_new ();

  for (i = 0; i < G_SIZEOF_MEMBER (KKey, bytes); ++i)
    {
      key->bytes [i] = (guint8) g_rand_int_range (rand, 0, G_MAXUINT8);
    }
  return key;
}

static gchar charset [] = "0123456789abcdef";

gchar* k_key_to_string (KKey* key)
{
  GString* builder = g_string_sized_new (1 + 6 * (K_KEY_BITLEN >> 3));
  guint8* bytes = key->bytes;
  gboolean first = TRUE;
  gint i;

  for (i = 0; i < (K_KEY_BITLEN >> 3); ++i)
    {
      guint8 byte = bytes [i];
      gchar buffer [] = { ',', ' ', '0', 'x', charset [byte >> 4], charset [byte & 0xf] };
      gint off = first ? 2 : 0;

      g_string_append_len (builder, buffer + off, G_N_ELEMENTS (buffer) - off);
      first = FALSE;
    }

  return g_string_free_and_steal (builder);
}
