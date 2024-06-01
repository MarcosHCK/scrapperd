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
#include <node.h>
#include <node.signals.h>

typedef struct _KNodeAction KNodeAction;
static void k_node_action_executor (KNodeAction* action, KNode* node);
static KNodeAction* k_node_action_ref (KNodeAction* action);
static void k_node_action_unref (KNodeAction* action);
static KNodeAction* k_node_action_new (guint signal_id, guint n_values);
#define k_node_action_value(action,nth) (&((&((action)->first))[(nth)]))

struct _KNodeAction
{
  guint refs;
  guint signal_id;
  guint n_values;
  guint done;
  GValue result;
  GValue instance;
  GValue first;
};

struct _KNodePrivate
{
  KBuckets* buckets;
  KKey* id;
  GThreadPool* pool;
};

enum
{
  prop_0,
  prop_id,
  prop_number,
};

enum
{
  sig_find_node,
  sig_find_value,
  sig_ping,
  sig_store,
  sig_number,
};

G_DEFINE_FINAL_TYPE_WITH_PRIVATE (KNode, k_node, G_TYPE_OBJECT)
static GParamSpec* properties [prop_number] = { 0 };
static guint signals [sig_number] = { 0 };

#define k_node_priv(pself) G_STRUCT_MEMBER (KNodePrivate*, pself, G_STRUCT_OFFSET (KNode, priv))

static void k_node_action_executor (KNodeAction* action, KNode* node)
{
  g_signal_emitv (& action->instance, action->signal_id, 0, & action->result);
  g_atomic_int_set (& action->done, TRUE);
}

static KNodeAction* k_node_action_ref (KNodeAction* action)
{
  return (g_atomic_int_inc (& action->refs), action);
}

static void k_node_action_unref (KNodeAction* action)
{
  if (g_atomic_int_dec_and_test (& action->refs))
    {
      guint i;

      for (i = 0; i < action->n_values; ++i)

        g_value_unset (k_node_action_value (action, i));

      g_free (action);
    }
}

static KNodeAction* k_node_action_new (guint signal_id, guint n_values)
{
  const gsize headsz = sizeof (KNodeAction) - G_SIZEOF_MEMBER (KNodeAction, first);
  const gsize valuesz = (n_values) * G_SIZEOF_MEMBER (KNodeAction, first);
  KNodeAction* action = g_malloc0 (headsz + valuesz);
  G_STRUCT_MEMBER (guint, action, G_STRUCT_OFFSET (KNodeAction, done)) = FALSE;
  G_STRUCT_MEMBER (guint, action, G_STRUCT_OFFSET (KNodeAction, n_values)) = n_values;
  G_STRUCT_MEMBER (guint, action, G_STRUCT_OFFSET (KNodeAction, refs)) = 1;
  G_STRUCT_MEMBER (guint, action, G_STRUCT_OFFSET (KNodeAction, signal_id)) = signal_id;
  return action;
}

static void k_node_init (KNode* self)
{
  GError* tmperr = NULL;
  KNodePrivate* priv = NULL;

  self->priv = (priv = k_node_get_instance_private (self));

  priv->buckets = k_buckets_new_with_base (priv->id = k_key_new_random ());
  priv->pool = g_thread_pool_new_full ((GFunc) k_node_action_executor, self, (GDestroyNotify) k_node_action_unref, K_NODE_ALPHA, FALSE, &tmperr);

  g_assert_no_error (tmperr);
}

static void k_node_class_finalize (GObject* pself)
{
  KNodePrivate* priv = k_node_priv (pself);

  k_buckets_free (priv->buckets);
  k_key_free (priv->id);

  G_OBJECT_CLASS (k_node_parent_class)->finalize (pself);
}

static KValue* k_node_class_find_node (KNode* node G_GNUC_UNUSED, KKey* peer G_GNUC_UNUSED, KKey* id G_GNUC_UNUSED)
{
  g_critical ("KNode::find-node signal is not handled");
  return NULL;
}

static KValue* k_node_class_find_value (KNode* node G_GNUC_UNUSED, KKey* peer G_GNUC_UNUSED, KKey* id G_GNUC_UNUSED)
{
  g_critical ("KNode::find-value signal is not handled");
  return NULL;
}

static void k_node_class_get_property (GObject* pself, guint property_id, GValue* value, GParamSpec* pspec)
{
  KNodePrivate* priv = k_node_priv (pself);

  switch (property_id)
    {
      case prop_id: g_value_set_boxed (value, priv->id); break;
      default: G_OBJECT_WARN_INVALID_PROPERTY_ID (pself, property_id, pspec);
    }
}

static gboolean k_node_class_ping (KNode* node G_GNUC_UNUSED, KKey* peer G_GNUC_UNUSED)
{
  g_critical ("KNode::ping signal is not handled");
  return FALSE;
}

static gboolean k_node_class_store (KNode* node G_GNUC_UNUSED, KKey* peer G_GNUC_UNUSED, KKey* id G_GNUC_UNUSED, GBytes* value G_GNUC_UNUSED)
{
  g_critical ("KNode::ping signal is not handled");
  return FALSE;
}

static void k_node_class_init (KNodeClass* klass)
{
  G_OBJECT_CLASS (klass)->finalize = k_node_class_finalize;
  G_OBJECT_CLASS (klass)->get_property = k_node_class_get_property;

  klass->find_node = k_node_class_find_node;
  klass->find_value = k_node_class_find_value;
  klass->ping = k_node_class_ping;
  klass->store = k_node_class_store;

  properties [prop_id] = g_param_spec_boxed ("id", "id", "id", K_TYPE_KEY, G_PARAM_STATIC_STRINGS | G_PARAM_READABLE);
  g_object_class_install_properties (G_OBJECT_CLASS (klass), prop_number, properties);

  signals [sig_find_node] = g_signal_new ("find-node", K_TYPE_NODE, G_SIGNAL_ACTION, G_STRUCT_OFFSET (KNodeClass, find_node), g_signal_accumulator_first_wins, NULL, g_cclosure_user_marshal_BOXED__BOXED_BOXED, K_TYPE_VALUE, 2, K_TYPE_KEY, K_TYPE_KEY);
  signals [sig_find_value] = g_signal_new ("find-value", K_TYPE_NODE, G_SIGNAL_ACTION, G_STRUCT_OFFSET (KNodeClass, find_value), g_signal_accumulator_first_wins, NULL, g_cclosure_user_marshal_BOXED__BOXED_BOXED, K_TYPE_VALUE, 2, K_TYPE_KEY, K_TYPE_KEY);
  signals [sig_ping] = g_signal_new ("ping", K_TYPE_NODE, G_SIGNAL_ACTION, G_STRUCT_OFFSET (KNodeClass, ping), g_signal_accumulator_first_wins, NULL, g_cclosure_user_marshal_BOOLEAN__BOXED, G_TYPE_BOOLEAN, 1, K_TYPE_KEY);
  signals [sig_store] = g_signal_new ("store", K_TYPE_NODE, G_SIGNAL_ACTION, G_STRUCT_OFFSET (KNodeClass, store), g_signal_accumulator_first_wins, NULL, g_cclosure_user_marshal_BOOLEAN__BOXED_BOXED_BOXED, G_TYPE_BOOLEAN, 3, K_TYPE_KEY, K_TYPE_KEY, G_TYPE_BYTES);
}

KKey* k_node_get_id (KNode* node)
{
  g_return_val_if_fail (K_IS_NODE (node), NULL);
  return node->priv->id;
}

struct _InsertData
{
  KKey* key;
  GBytes* value;
};

static void _insert_data_free (struct _InsertData* data)
{
  k_key_free (data->key);
  g_bytes_unref (data->value);
}

static struct _InsertData* _insert_data_new (KKey* key, GBytes* value)
{
  struct _InsertData* data = g_slice_new (struct _InsertData);
  data->key = k_key_copy (key);
  data->value = g_bytes_ref (value);
  return data;
}

static void k_node_insert_func (GTask* task, KNode* node, struct _InsertData* data, GCancellable* cancellable)
{
  GBytes* value = data->value;
  GSList *link, *list;
  KKey** dyn_peers = NULL;
  KKey* key = data->key;
  KKey* stt_peers [K_BUCKET_MAXSPAN];
  KKey** peers;
  KNodePrivate* priv = node->priv;
  guint i, n_peers, used = 0;

  n_peers = g_slist_length (list = k_buckets_nearest (priv->buckets, key));
  peers = G_N_ELEMENTS (stt_peers) >= n_peers ? stt_peers : (dyn_peers = g_new (KKey*, n_peers));

  for (i = 0, link = list; link; link = link->next, ++i)
    {
      peers [i] = link->data;
    }

  while (n_peers > 0)
    {
      KKey** next = & peers [used];
      KNodeAction *action, *actions [K_NODE_ALPHA];
      guint hold, taken = MIN (n_peers, K_NODE_ALPHA);

      n_peers -= taken;
      used += taken;

      for (i = 0; i < taken; ++i)
        {
          actions [i] = (action = k_node_action_new (signals [sig_store], 3));

          g_value_init_from_instance (& action->instance, node);

          g_value_init (& action->result, G_TYPE_BOOLEAN);
          g_value_init (k_node_action_value (action, 0), K_TYPE_KEY);
          g_value_init (k_node_action_value (action, 1), K_TYPE_KEY);
          g_value_init (k_node_action_value (action, 2), G_TYPE_BYTES);

          g_value_set_boxed (k_node_action_value (action, 0), next [i]);
          g_value_set_boxed (k_node_action_value (action, 1), key);
          g_value_set_boxed (k_node_action_value (action, 2), value);

          g_thread_pool_push (priv->pool, k_node_action_ref (action), NULL);
        }

      do
        {
          for (i = 0, hold = 0; i < taken; ++i)

            if (actions [i] != NULL && (++hold, g_atomic_int_get (& actions [i]->done) == TRUE))
              {
                gboolean good;

                if ((good = g_value_get_boolean (& actions [i]->result)) == TRUE)
                  {
                    g_task_return_boolean (task, TRUE);

                    for (i = 0; i < taken; ++i)

                      g_clear_pointer (& actions [i], k_node_action_unref);

                    g_free (dyn_peers);
                    g_slist_free_full (list, (GDestroyNotify) k_key_free);
                    return;
                  }

                g_clear_pointer (& actions [i], k_node_action_unref);
              }
        }
      while (hold > 0);
    }

  g_task_return_new_error (task, G_IO_ERROR, G_IO_ERROR_FAILED, "no peer could store this key");
  g_free (dyn_peers);
  g_slist_free_full (list, (GDestroyNotify) k_key_free);
}

void k_node_insert (KNode* node, const KKey* key, GBytes* value, GCancellable* cancellable, GAsyncReadyCallback callback, gpointer user_data)
{
  GTask* task = g_task_new (node, cancellable, callback, user_data);

  g_task_set_check_cancellable (task, TRUE);
  g_task_set_priority (task, G_PRIORITY_HIGH);
  g_task_set_return_on_cancel (task, TRUE);
  g_task_set_source_tag (task, k_node_insert_func);
  g_task_set_task_data (task, _insert_data_new ((KKey*) key, value), (GDestroyNotify) _insert_data_free);
  g_task_run_in_thread (task, (GTaskThreadFunc) k_node_insert_func);
  g_object_unref (task);
}

gboolean k_node_insert_finish (KNode* node, GAsyncResult* result, GError** error)
{
  return g_task_propagate_boolean (G_TASK (result), error);
}

static void k_node_lookup_func (GTask* task, KNode* node, KKey* key, GCancellable* cancellable)
{
  GSList *list, *link;
  KKey** dyn_peers = NULL;
  KKey* stt_peers [K_BUCKET_MAXSPAN];
  KKey** peers;
  KNodePrivate* priv = node->priv;
  guint i, n_peers, used = 0;

  n_peers = g_slist_length (list = k_buckets_nearest (priv->buckets, key));
  peers = G_N_ELEMENTS (stt_peers) >= n_peers ? stt_peers : (dyn_peers = g_new (KKey*, n_peers));

  for (i = 0, link = list; link; link = link->next, ++i)
    {
      peers [i] = link->data;
    }

  while (n_peers > 0)
    {
      KKey** next = & peers [used];
      KNodeAction *action, *actions [K_NODE_ALPHA];
      guint hold, taken = MIN (n_peers, K_NODE_ALPHA);

      n_peers -= taken;
      used += taken;

      for (i = 0; i < taken; ++i)
        {
          actions [i] = (action = k_node_action_new (signals [sig_find_value], 2));

          g_value_init_from_instance (& action->instance, node);

          g_value_init (& action->result, K_TYPE_VALUE);
          g_value_init (k_node_action_value (action, 0), K_TYPE_KEY);
          g_value_init (k_node_action_value (action, 1), K_TYPE_KEY);

          g_value_set_boxed (k_node_action_value (action, 0), next [i]);
          g_value_set_boxed (k_node_action_value (action, 1), key);

          g_thread_pool_push (priv->pool, k_node_action_ref (action), NULL);
        }

      do
        {
          for (i = 0, hold = 0; i < taken; ++i) if (actions [i] != NULL && (++hold, g_atomic_int_get (& actions [i]->done) == TRUE))
            {
              KValue* value;

              if ((value = g_value_get_boxed (& actions [i]->result)) != NULL)
                {
                  g_assert (k_value_is_inmediate (value) == TRUE);
                  g_task_return_pointer (task, g_bytes_ref (value->inmediate), (GDestroyNotify) g_bytes_unref);

                  for (i = 0; i < taken; ++i)

                    g_clear_pointer (& actions [i], k_node_action_unref);

                  g_free (dyn_peers);
                  g_slist_free_full (list, (GDestroyNotify) k_key_free);
                  return;
                }

              g_clear_pointer (& actions [i], k_node_action_unref);
            }
        }
      while (hold > 0);
    }

  g_task_return_new_error (task, G_IO_ERROR, G_IO_ERROR_NOT_FOUND, "key not found");
  g_free (dyn_peers);
  g_slist_free_full (list, (GDestroyNotify) k_key_free);
}

void k_node_lookup (KNode* node, const KKey* key, GCancellable* cancellable, GAsyncReadyCallback callback, gpointer user_data)
{
  GTask* task = g_task_new (node, cancellable, callback, user_data);

  g_task_set_check_cancellable (task, TRUE);
  g_task_set_priority (task, G_PRIORITY_HIGH);
  g_task_set_return_on_cancel (task, TRUE);
  g_task_set_source_tag (task, k_node_lookup_func);
  g_task_set_task_data (task, k_key_copy ((KKey*) key), (GDestroyNotify) k_key_free);
  g_task_run_in_thread (task, (GTaskThreadFunc) k_node_lookup_func);
  g_object_unref (task);
}

GBytes* k_node_lookup_finish (KNode* node, GAsyncResult* result, GError** error)
{
  return g_task_propagate_pointer (G_TASK (result), error);
}

GSList* k_node_nearest (KNode* node, const KKey* key)
{
  return k_buckets_nearest (node->priv->buckets, (KKey*) key);
}

KNode* k_node_new ()
{
  return g_object_new (K_TYPE_NODE, NULL);
}
