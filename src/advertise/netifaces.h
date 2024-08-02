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
#ifndef __ADV_NET_IFACES__
#define __ADV_NET_IFACES__ 1
#include <gio/gio.h>

typedef struct _AdvNetIfacesInfo AdvNetIfacesInfo;

#if __cplusplus
extern "C" {
#endif // __cplusplus

  struct _AdvNetIfacesInfo
    {
      GSocketAddress* address;
      gchar* name;
      GSocketAddress *netmask;

      guint loopback : 1;
      guint ppp : 1;

      union
        {
          GSocketAddress* broadcast;
          GSocketAddress* peer;
        };
    };

  G_GNUC_INTERNAL AdvNetIfacesInfo** adv_net_ifaces_enumerate (GSocketFamily family, GError** error);
  G_GNUC_INTERNAL void adv_net_ifaces_info_free (AdvNetIfacesInfo* info);
  G_GNUC_INTERNAL GSocketAddress* adv_net_ifaces_info_get_broadcast (AdvNetIfacesInfo* info);
  G_GNUC_INTERNAL GSocketAddress* adv_net_ifaces_info_get_peer (AdvNetIfacesInfo* info);

#if __cplusplus
}
#endif // __cplusplus

#endif // __ADV_NET_IFACES__
