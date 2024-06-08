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
#ifndef __KADEMLIA_PEERACTION__
#define __KADEMLIA_PEERACTION__ 1
#include <glib-object.h>

typedef struct _KRpcCall KRpcCall;

#if __cplusplus
extern "C" {
#endif // __cplusplus

  struct _KRpcCall
    {
      gint refs;
      guint signal_id;
      guint n_values;
      guint done;
      guint failable;
      GValue result;
      GValue instance;
      GValue first;
    };

  static __inline void k_rpc_call_executor (KRpcCall* call);
  static __inline KRpcCall* k_rpc_call_new (guint signal_id, guint n_values);
  static __inline KRpcCall* k_rpc_call_new_failable (guint signal_id, guint n_values);
  static __inline KRpcCall* k_rpc_call_ref (KRpcCall* call);
  static __inline gboolean k_rpc_call_send (KRpcCall* call, GThreadPool* pool, GError** error);
  static __inline void k_rpc_call_send_no_reply (KRpcCall* call, GThreadPool* pool);
  static __inline void k_rpc_call_unref (KRpcCall* call);

  #define k_rpc_call_get_done(call) (G_GNUC_EXTENSION ({ \
 ; \
    const KRpcCall* __call = (call); \
    g_atomic_int_get (& __call->done); \
  }))

  #define k_rpc_call_nth_value(call,nth) (G_GNUC_EXTENSION ({ \
 ; \
    const KRpcCall* __call = (call); \
    const guint __nth = (nth); \
    (GValue*) &((&__call->first) [__nth]); \
  }))

  static __inline void k_rpc_call_executor (KRpcCall* call)
    {
      GSignalQuery query;
      guint i;

      g_signal_query (call->signal_id, &query);
      g_print ("rpc signal: %s::%s\n", g_type_name (query.itype), query.signal_name);

      for (i = 0; i < call->n_values; ++i)
        {
          GType type = G_VALUE_TYPE (k_rpc_call_nth_value (call, i));

          g_print ("- rpc argument %i: %s\n", i, g_type_name (type));
        }

      g_signal_emitv (&call->instance, call->signal_id, 0, &call->result);
      g_atomic_int_set (&call->done, TRUE);
      k_rpc_call_unref (call);
    }

  static __inline KRpcCall* k_rpc_call_new (guint signal_id, guint n_values)
    {
      const gsize headsz = sizeof (KRpcCall) - G_SIZEOF_MEMBER (KRpcCall, first);
      const gsize valuesz = (n_values) * G_SIZEOF_MEMBER (KRpcCall, first);
      KRpcCall* call = (KRpcCall*) g_malloc0 (headsz + valuesz);
      G_STRUCT_MEMBER (guint, call, G_STRUCT_OFFSET (KRpcCall, done)) = FALSE;
      G_STRUCT_MEMBER (guint, call, G_STRUCT_OFFSET (KRpcCall, failable)) = FALSE;
      G_STRUCT_MEMBER (guint, call, G_STRUCT_OFFSET (KRpcCall, n_values)) = n_values;
      G_STRUCT_MEMBER (guint, call, G_STRUCT_OFFSET (KRpcCall, signal_id)) = signal_id;
      g_atomic_ref_count_init (&call->refs);
      return call;
    }

  static __inline KRpcCall* k_rpc_call_new_failable (guint signal_id, guint n_values)
    {
      KRpcCall* call = k_rpc_call_new (signal_id, 1 + n_values);
      g_value_init (k_rpc_call_nth_value (call, n_values), G_TYPE_POINTER);
      g_value_set_pointer (k_rpc_call_nth_value (call, n_values), NULL);
      G_STRUCT_MEMBER (guint, call, G_STRUCT_OFFSET (KRpcCall, failable)) = TRUE;
      return call;
    }

  static __inline KRpcCall* k_rpc_call_ref (KRpcCall* call)
    {
      g_return_val_if_fail (call != NULL, NULL);
      return (g_atomic_ref_count_inc (& call->refs), call);
    }

  static __inline gboolean k_rpc_call_send (KRpcCall* call, GThreadPool* pool, GError** error)
    {
      GError* tmperr = NULL;
      GValue* value = k_rpc_call_nth_value (call, call->n_values - 1);
      gboolean failed = FALSE;

      k_rpc_call_ref (call);

      if (call->failable == TRUE)
        {
          g_value_set_pointer (value, &tmperr);
        }

      g_thread_pool_push (pool, k_rpc_call_ref (call), NULL);

      while (g_atomic_int_get (&call->done) != TRUE)

        g_thread_yield ();

      if (call->failable == TRUE)
        {
          g_value_set_pointer (value, NULL);
        }

      if (call->failable == TRUE && (failed = G_UNLIKELY (tmperr != NULL)))
        {
          g_propagate_error (error, tmperr);
        }
      return (k_rpc_call_unref (call), failed == FALSE);
    }

  static __inline void k_rpc_call_send_no_reply (KRpcCall* call, GThreadPool* pool)
    {
      g_thread_pool_push (pool, k_rpc_call_ref (call), NULL);
    }

  static __inline void k_rpc_call_unref (KRpcCall* call)
    {
      if (call != NULL && g_atomic_ref_count_dec (& call->refs))
        {
          guint i;
          g_value_unset (& call->result);
          g_value_unset (& call->instance);

          for (i = 0; i < call->n_values; ++i)
            
            g_value_unset (k_rpc_call_nth_value (call, i));

          g_free (call);
        }
    }

#if __cplusplus
}
#endif // __cplusplus

#endif // __KADEMLIA_PEERACTION__
