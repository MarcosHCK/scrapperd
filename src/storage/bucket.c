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
#include <bucket.h>

typedef struct _KBucket KBucket;
static GSList* _k_buckets_search (KBuckets* buckets, KKey* id, gboolean create);
static GSList* _k_buckets_search_index (KBuckets* buckets, guint index, gboolean create);

#define _g_slist_data0(var) (G_GNUC_EXTENSION ({ GSList* __var = (var); ((__var == NULL) ? NULL : (__var->data)); }))
#define _g_slist_free_full0(var,dd) ((var == NULL) ? NULL : (var = (g_slist_free_full ((var), (dd)), NULL)))
#define _g_slist_insert_sorted0(var,val,cmp) (var = g_slist_insert_sorted ((var), (val), (cmp)))
#define _g_slist_prepend0(var,val) (var = g_slist_prepend ((var), (val)))

struct _KBucket
{
  guint index;
  GQueue nodes;
  GQueue replacements;
  GQueue stale;
};

struct _KBuckets
{
  KKey* base;
  GSList* buckets;
};

#define k_bucket_new(index_) (G_GNUC_EXTENSION ({ \
 ; \
    KBucket* __bucket = g_slice_new0 (KBucket); \
    guint __index = (index_); \
    (__bucket->index = __index, __bucket); \
  }))

#define k_buckets_new() (g_slice_new0 (KBuckets))

void k_buckets_drop (KBuckets* buckets, KKey* id, gboolean force)
{
  g_return_if_fail (buckets != NULL);
  g_return_if_fail (id != NULL);
  KBucket* bucket = _g_slist_data0 (_k_buckets_search (buckets, id, FALSE));
  KKey* key;
  GList* link;

  if (bucket != NULL && NULL != (link = g_queue_find_custom (& bucket->nodes, id, (GCompareFunc) k_key_equal)))
    {
      force = force || g_queue_get_length (& bucket->replacements) > 0;

      if (force == FALSE)
        {
          g_queue_push_head (& bucket->stale, link->data);
        }
      else
        {
          g_queue_delete_link (& bucket->nodes, link);
          g_queue_remove (& bucket->stale, link->data);

          g_queue_push_head (& bucket->nodes, key = g_queue_pop_head (& bucket->replacements));
        }
    }
}

static void bucket_free (KBucket* self)
{
  if (self != NULL)
    {
      g_queue_clear_full (& self->nodes, (GDestroyNotify) k_key_free);
    }
}

void k_buckets_free (KBuckets* self)
{
  if (self != NULL)
    {
      _g_slist_free_full0 (self->buckets, (GDestroyNotify) bucket_free);
    }
}

gboolean k_buckets_insert (KBuckets* buckets, KKey* id)
{
  g_return_val_if_fail (buckets != NULL, FALSE);
  g_return_val_if_fail (id != NULL, FALSE);
  KBucket* bucket = _k_buckets_search (buckets, id, TRUE)->data;

  if (g_queue_get_length (& bucket->nodes) < K_BUCKET_MAXSPAN)
    {
      return (g_queue_push_head (& bucket->nodes, k_key_copy (id)), TRUE);
    }
  else
    {
      return (g_queue_push_head (& bucket->replacements, k_key_copy (id)), FALSE);
    }
}

KBuckets* k_buckets_new_with_base (KKey* id)
{
  g_return_val_if_fail (id != NULL, NULL);
  KBuckets* self;

  return ((self = k_buckets_new ())->base = k_key_copy (id), self);
}

GSList* k_buckets_nearest (KBuckets* buckets, KKey* id)
{
  g_return_val_if_fail (buckets != NULL, NULL);
  g_return_val_if_fail (id != NULL, NULL);
  KKey* distance = k_key_distance (buckets->base, id);
  GSList *link, *result = NULL;
  guint i;

  for (i = 0; i < K_KEY_BITLEN; ++i) if (k_key_nth_bit (distance, i) == 1)
    {
      if ((link = _k_buckets_search_index (buckets, i, FALSE)) != NULL)

        break;
    }

  if (link == NULL)
    {
      _g_slist_prepend0 (result, k_key_copy (buckets->base));
      link = buckets->buckets;
    }

  if (link != NULL)
    {
      guint got = 0;

      for (; link && got < K_BUCKET_MAXSPAN; link = link->next)
        {
          GList* head;

          for (head = g_queue_peek_head_link (& ((KBucket*) link->data)->nodes); head && got < K_BUCKET_MAXSPAN; head = head->next)
            {
              _g_slist_prepend0 (result, k_key_copy (head->data));
              ++got;
            }
        }
    }

  return g_slist_reverse (result);
}

void k_bucket_promote (KBuckets* buckets, KKey* id)
{
  g_return_if_fail (buckets != NULL);
  g_return_if_fail (id != NULL);
  KBucket* bucket = _g_slist_data0 (_k_buckets_search (buckets, id, FALSE));
  GList* link;

  if (bucket != NULL && NULL != (link = g_queue_find_custom (& bucket->nodes, id, (GCompareFunc) k_key_equal)))
    {
      g_queue_delete_link (& bucket->nodes, link);
      g_queue_push_head_link (& bucket->nodes, link);
    }
}

static GSList* _k_buckets_search (KBuckets* buckets, KKey* id, gboolean create)
{
  KKey* distance = k_key_distance (buckets->base, id);
  guint i;

  for (i = 0; i < K_KEY_BITLEN; ++i) if (k_key_nth_bit (distance, i) == 1)
    {
      k_key_free (distance);
      return _k_buckets_search_index (buckets, K_KEY_BITLEN - (i + 1), create);
    }
  return (k_key_free (distance), NULL);
}

static gint compare_index (KBucket* bucket, gpointer index)
{
  return bucket->index - GPOINTER_TO_UINT (index);
}

static gint compare_index2 (KBucket* bucket, KBucket* bucket2)
{
  return bucket->index - bucket2->index;
}

static GSList* _k_buckets_search_index (KBuckets* buckets, guint index, gboolean create)
{
  GSList* link;
  const GCompareFunc cmp1 = (GCompareFunc) compare_index;
  const GCompareFunc cmp2 = (GCompareFunc) compare_index2;
  const gpointer pidx = GUINT_TO_POINTER (index);

  while (TRUE)
    {
      if ((link = g_slist_find_custom (buckets->buckets, pidx, cmp1)) != NULL)
        {
          return link;
        }
      else if (create == FALSE) return NULL; else
        {
          _g_slist_insert_sorted0 (buckets->buckets, k_bucket_new (index), cmp2);
          continue;
        }
    }

  g_assert_not_reached ();
}
