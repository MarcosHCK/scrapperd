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
#include <interface.h>

#if defined(G_OS_WIN32)
# include <interface-win32.c>
#elif defined(G_OS_UNIX)
# include <interface-unix.c>
#endif

void nd_interface_info_free (NdInterfaceInfo* info)
{
  g_clear_pointer (&info->address, g_object_unref);
  g_clear_pointer (&info->name, g_free);
  g_clear_pointer (&info->netmask, g_object_unref);
  g_clear_pointer (&info->peer, g_object_unref);
  g_slice_free (NdInterfaceInfo, info);
}

GSocketAddress* nd_interface_info_get_broadcast (NdInterfaceInfo* info)
{
  return (info->loopback || info->ppp) == TRUE ? NULL : info->broadcast;
}

GSocketAddress* nd_interface_info_get_peer (NdInterfaceInfo* info)
{
  return (info->loopback || info->ppp) == FALSE ? NULL : info->peer;
}
