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
#ifndef __ADV_IPV4_CHANNEL__
#define __ADV_IPV4_CHANNEL__ 1
#include <gio/gio.h>

typedef struct _SendToData SendToData;

#if __cplusplus
extern "C" {
#endif // __cplusplus

  struct _SendToData
    {
      GBytes* bytes;
      GList* ifaces;
      GSocket* socket;
    };

  G_STATIC_ASSERT (sizeof (gsize) == G_SIZEOF_MEMBER (GOutputVector, size));

  static void _runner (GTask* task, gpointer channel, SendToData* data, GCancellable* cancellable)
    {
      guint i, length = g_list_length (data->ifaces);
      GError* tmperr = NULL;
      GOutputMessage stat_messages [8], *dyn_messages = NULL, *messages;
      GOutputVector stat_vectors [8], *dyn_vectors = NULL, *vectors;
      GList* link;

      if (G_N_ELEMENTS (stat_messages) >= length)

        messages = & stat_messages [0];
      else
        messages = dyn_messages = g_new (GOutputMessage, length);

      if (G_N_ELEMENTS (stat_vectors) >= length)

        vectors = & stat_vectors [0];
      else
        vectors = dyn_vectors = g_new (GOutputVector, length);

      for (link = data->ifaces, i = 0; link; link = link->next, ++i)
        {
          messages [i].address = G_SOCKET_ADDRESS (link->data);
          messages [i].bytes_sent = 0;
          messages [i].control_messages = NULL;
          messages [i].num_control_messages = 0;
          messages [i].num_vectors = 1;
          messages [i].vectors = & vectors [i];

          vectors [i].buffer = g_bytes_get_data (data->bytes, & vectors [i].size);
        }

      i = g_datagram_based_send_messages (G_DATAGRAM_BASED (data->socket), messages, length, 0, -1, cancellable, &tmperr);

      g_clear_pointer (&dyn_messages, g_free);
      g_clear_pointer (&dyn_vectors, g_free);

      if (G_UNLIKELY (tmperr != NULL))

        g_task_return_error (task, tmperr);
      else
        g_task_return_boolean (task, i > 0);
    }

  static void _send_to_data_free (gpointer mem)
    {
      g_clear_pointer (&G_STRUCT_MEMBER (GBytes*, mem, G_STRUCT_OFFSET (SendToData, bytes)), (GDestroyNotify) g_bytes_unref);
      g_clear_object (&G_STRUCT_MEMBER (GSocket*, mem, G_STRUCT_OFFSET (SendToData, socket)));
      g_slice_free (SendToData, mem);
    }

  static __inline void adv_ipv4_channel_send_to (gpointer channel, GSocket* socket, GList* ifaces, GBytes* bytes, GCancellable* cancellable, GAsyncReadyCallback callback, gpointer user_data)
    {
      SendToData* data;
      GTask* task;

      data = g_slice_new (SendToData);
      task = g_task_new (channel, cancellable, callback, user_data);

      data->bytes = g_bytes_ref (bytes);
      data->ifaces = ifaces;
      data->socket = g_object_ref (socket);

      g_task_set_check_cancellable (task, TRUE);
      g_task_set_priority (task, G_PRIORITY_DEFAULT);
      g_task_set_source_tag (task, adv_ipv4_channel_send_to);
      g_task_set_task_data (task, data, _send_to_data_free);
      g_task_run_in_thread (task, (GTaskThreadFunc) _runner);
      g_object_unref (task);
    }

  static __inline gboolean adv_ipv4_channel_send_to_finish (gpointer channel, GAsyncResult* result, GError** error)
    {
      return g_task_propagate_boolean (G_TASK (result), error);
    }

#if __cplusplus
}
#endif // __cplusplus

#endif // __ADV_IPV4_CHANNEL__
