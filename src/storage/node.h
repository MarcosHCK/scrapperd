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
#ifndef __K_NODE__
#define __K_NODE__ 1
#include <gio/gio.h>
#include <key.h>
#include <value.h>

#define K_TYPE_NODE (k_node_get_type ())
#define K_IS_NODE(obj) (G_TYPE_CHECK_INSTANCE_TYPE ((obj), K_TYPE_NODE))
#define K_NODE(obj) (G_TYPE_CHECK_INSTANCE_CAST ((obj), K_TYPE_NODE, KNode))
typedef struct _KNode KNode;
typedef struct _KNodePrivate KNodePrivate;
#define K_IS_NODE_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((obj), K_TYPE_NODE))
#define K_NODE_CLASS(klass) (G_TYPE_CHECK_CLASS_CAST ((obj), K_TYPE_NODE, KNodeClass))
#define K_NODE_GET_CLASS(klass) (G_TYPE_INSTANCE_GET_CLASS ((obj), K_TYPE_NODE, KNodeClass))
typedef struct _KNodeClass KNodeClass;

#define K_NODE_ALPHA 3

#if __cplusplus
extern "C" {
#endif // __cplusplus

  struct _KNode
    {
      GObject parent;
      KNodePrivate* priv;
    };

  struct _KNodeClass
    {
      GObjectClass parent;
      KValue* (* find_node) (KNode* node, KKey* peer, KKey* id);
      KValue* (* find_value) (KNode* node, KKey* peer, KKey* id);
      gboolean (* ping) (KNode* node, KKey* peer);
      gboolean (* store) (KNode* node, KKey* peer, KKey* id, GBytes* value);
    };

  GType k_node_get_type (void) G_GNUC_CONST;

  void k_node_demote (KNode* node, const KKey* peer);
  KKey* k_node_get_id (KNode* node);
  void k_node_insert (KNode* node, const KKey* key, GBytes* value, GCancellable* cancellable, GAsyncReadyCallback callback, gpointer user_data);
  gboolean k_node_insert_finish (KNode* node, GAsyncResult* result, GError** error);
  void k_node_lookup (KNode* node, const KKey* key, GCancellable* cancellable, GAsyncReadyCallback callback, gpointer user_data);
  GBytes* k_node_lookup_finish (KNode* node, GAsyncResult* result, GError** error);
  GSList* k_node_nearest (KNode* node, const KKey* key);
  KNode* k_node_new (void);

#if __cplusplus
}
#endif // __cplusplus

#endif // __K_NODE__
