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
#ifndef __K_BUCKET__
#define __K_BUCKET__ 1
#include <key.h>

#define K_BUCKET_MAXSPAN 20  /* called K in literature */
typedef struct _KBuckets KBuckets;

#if __cplusplus
extern "C" {
#endif // __cplusplus

  void k_buckets_free (KBuckets* buckets);
  void k_buckets_drop (KBuckets* buckets, KKey* id, gboolean force);
  KBuckets* k_buckets_new_with_base (KKey* id);
  gboolean k_buckets_insert (KBuckets* buckets, KKey* id);
  GSList* k_buckets_nearest (KBuckets* buckets, KKey* id);
  void k_bucket_promote (KBuckets* buckets, KKey* id);

#if __cplusplus
}
#endif // __cplusplus

#endif // __K_BUCKET__
