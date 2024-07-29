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
#ifndef __KADEMLIA_RUNNER__
#define __KADEMLIA_RUNNER__ 1
#include <glib.h>

typedef struct _KRunnerData KRunnerData;

#if __cplusplus
extern "C" {
#endif // __cplusplus

  struct _KRunnerData
    {
      guint* dones;
      GMainLoop* loop;
      guint n_dones;
    };

  static __inline void k_runner (GMainContext* context, guint* dones, guint n_dones);
  static __inline int k_runner_source (KRunnerData* data);

  static __inline void k_runner (GMainContext* context, guint* dones, guint n_dones)
    {
      KRunnerData data = { .dones = dones, .n_dones = n_dones };
      GSource* source = g_idle_source_new ();

      data.loop = g_main_loop_new (context, TRUE);

      g_source_set_callback (source, G_SOURCE_FUNC (k_runner_source), &data, NULL);
      g_source_set_priority (source, G_PRIORITY_HIGH_IDLE);
      g_source_set_static_name (source, "Kademlia.runner+source");
      g_source_attach (source, context);
      g_source_unref (source);

      g_main_loop_run (data.loop);
      g_main_loop_unref (data.loop);
    }

  static __inline int k_runner_source (KRunnerData* data)
    {
      guint i, pending = 0;

      for (i = 0; i < data->n_dones; ++i)

        pending |= g_atomic_int_get (& data->dones [i]) ^ 1;

      return pending > 0 ? G_SOURCE_CONTINUE : (g_main_loop_quit (data->loop), G_SOURCE_REMOVE);
    }

#if __cplusplus
}
#endif // __cplusplus

#endif // __KADEMLIA_RUNNER__
