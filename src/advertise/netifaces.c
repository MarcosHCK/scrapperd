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
#include <netifaces.h>

void adv_net_ifaces_info_free (AdvNetIfacesInfo* info)
{
  g_clear_pointer (&info->address, g_object_unref);
  g_clear_pointer (&info->name, g_free);
  g_clear_pointer (&info->netmask, g_object_unref);
  g_clear_pointer (&info->peer, g_object_unref);
  g_slice_free (AdvNetIfacesInfo, info);
}

GSocketAddress* adv_net_ifaces_info_get_broadcast (AdvNetIfacesInfo* info)
{
  return (info->loopback || info->ppp) == TRUE ? NULL : info->broadcast;
}

GSocketAddress* adv_net_ifaces_info_get_peer (AdvNetIfacesInfo* info)
{
  return (info->loopback || info->ppp) == FALSE ? NULL : info->peer;
}
