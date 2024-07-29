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
#ifndef __KADEMLIA_BUCKET__
#define __KADEMLIA_BUCKET__ 1
#include <glib.h>

typedef struct _KKey KKey;
typedef struct _KBucket KBucket;
typedef struct _KStaleContact KStaleContact;

#if __cplusplus
extern "C" {
#endif // __cplusplus

  struct _KBucket
    {
      guint index;
      GQueue nodes;
      GQueue replacements;
      GQueue stale;
    };

  struct _KStaleContact
    {
      guint drop_count;
      KKey* key;
    };

  KKey* k_key_copy (KKey * self);
  void k_key_free (KKey * self);

  #define k_bucket_get_nodes(val) (&(val)->nodes)
  #define k_bucket_get_replacements(val) (&(val)->replacements)
  #define k_bucket_get_stale(val) (&(val)->stale)

  static __inline void k_bucket_destroy (KBucket* bucket);
  static __inline void k_bucket_init (KBucket* bucket, guint index);
  static __inline void k_stale_contact_copy (KStaleContact* src, KStaleContact* dst);
  static __inline void k_stale_contact_destroy (KStaleContact* contact);
  static __inline void k_stale_contact_init (KStaleContact* contact, KKey* key);

  static __inline void k_bucket_destroy (KBucket* bucket)
    {
      g_queue_clear_full (& bucket->nodes, (GDestroyNotify) k_key_free);
      g_queue_clear_full (& bucket->replacements, (GDestroyNotify) k_key_free);
      g_queue_clear_full (& bucket->stale, (GDestroyNotify) k_stale_contact_destroy);
    }

  static __inline void k_bucket_init (KBucket* bucket, guint index)
    {
      g_return_if_fail (index < G_MAXINT);

      bucket->index = index;
      g_queue_init (& bucket->nodes);
      g_queue_init (& bucket->replacements);
      g_queue_init (& bucket->stale);
    }

  static __inline gboolean k_queue_bring_front (GQueue* queue, gpointer data, GCompareFunc func)
    {
      GList* link;

      if ((link = g_queue_find_custom (queue, data, func)) == NULL)

        return FALSE;
      else
        {
          g_queue_unlink (queue, link);
          g_queue_push_head_link (queue, link);
        }
      return TRUE;
    }

  static __inline void k_stale_contact_copy (KStaleContact* src, KStaleContact* dst)
    {
      k_stale_contact_init (dst, src->key);
    }

  static __inline void k_stale_contact_destroy (KStaleContact* contact)
    {
      g_clear_pointer (& contact->key, (GDestroyNotify) k_key_free);
    }

  static __inline void k_stale_contact_init (KStaleContact* contact, KKey* key)
    {
      g_return_if_fail (key != NULL);

      contact->drop_count = 0;
      contact->key = k_key_copy (key);
    }

#if __cplusplus
}
#endif // __cplusplus

#endif // __KADEMLIA_BUCKET__
