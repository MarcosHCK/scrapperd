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
#include <netconf.h>
#include <netifaces.h>
#include <glib-unix.h>

#include <sys/types.h>
#include <sys/socket.h>
#include <net/if.h>
#include <netdb.h>
#ifdef HAVE_SOCKET_IOCTLS
# include <sys/ioctl.h>
# include <netinet/in.h>
# include <arpa/inet.h>
# if defined(__sun)
#  include <unistd.h>
#  include <stropts.h>
#  include <sys/sockio.h>
# endif
#endif // HAVE_SOCKET_IOCTLS

#include <netinet/in.h>
# if defined(HAVE_NETASH_ASH_H)
#  include <netash/ash.h>
# endif
# if defined(HAVE_NETATALK_AT_H)
#  include <netatalk/at.h>
# endif
# if defined(HAVE_NETAX25_AX25_H)
#  include <netax25/ax25.h>
# endif
# if defined(HAVE_NETECONET_EC_H)
#  include <neteconet/ec.h>
# endif
# if defined(HAVE_NETIPX_IPX_H)
#  include <netipx/ipx.h>
# endif
# if defined(HAVE_NETPACKET_PACKET_H)
#  include <netpacket/packet.h>
# endif
# if defined(HAVE_NETROSE_ROSE_H)
#  include <netrose/rose.h>
# endif
# if defined(HAVE_LINUX_IRDA_H)
#  include <linux/irda.h>
# endif
# if defined(HAVE_LINUX_ATM_H)
#  include <linux/atm.h>
# endif
# if defined(HAVE_LINUX_LLC_H)
#  include <linux/llc.h>
# endif
# if defined(HAVE_LINUX_TIPC_H)
#  include <linux/tipc.h>
# endif
# if defined(HAVE_LINUX_DN_H)
#  include <linux/dn.h>
# endif

#ifdef HAVE_SOCKADDR_SA_LEN
# define SA_LEN(sa)      sa->sa_len
#else // !HAVE_SOCKADDR_SA_LEN
# define SA_LEN(sa) af_to_len(sa->sa_family)
# ifdef HAVE_SIOCGLIFNUM
#  define SS_LEN(sa) af_to_len(sa->ss_family)
# else // !HAVE_SIOCGLIFNUM
#  define SS_LEN(sa) SA_LEN(sa)
# endif // HAVE_SIOCGLIFNUM
#endif // HAVE_SOCKADDR_SA_LEN

#ifdef HAVE_IFADDRS
# include <ifaddrs.h>
#endif // HAVE_IFADDRS

#define _g_free0(var) ((var == NULL) ? NULL : (var = (g_free (var), NULL)))

#if !defined (HAVE_GETIFADDRS) && (!defined (HAVE_SOCKET_IOCTLS) || !defined (HAVE_SIOCGIFCONF))
/*
 * If you're seeing this, it means you need to write suitable code to retrieve
 * interface information on your system.
 */
# error You need to add code for your platform.
#endif

#if HAVE_SIOCGLIFNUM
# define CNAME(x) l##x
#else
# define CNAME(x) x
#endif

static guint af_to_len (int af) 
{
  switch (af)
    {
      case AF_INET: return sizeof (struct sockaddr_in);
  #if defined(AF_INET6) && defined(HAVE_SOCKADDR_IN6)
      case AF_INET6: return sizeof (struct sockaddr_in6);
  #endif
  #if defined(AF_AX25) && defined(HAVE_SOCKADDR_AX25)
  #  if defined(AF_NETROM)
      case AF_NETROM: /* I'm assuming this is carried over x25 */
  #  endif
      case AF_AX25: return sizeof (struct sockaddr_ax25);
  #endif
  #if defined(AF_IPX) && defined(HAVE_SOCKADDR_IPX)
      case AF_IPX: return sizeof (struct sockaddr_ipx);
  #endif
  #if defined(AF_APPLETALK) && defined(HAVE_SOCKADDR_AT)
      case AF_APPLETALK: return sizeof (struct sockaddr_at);
  #endif
  #if defined(AF_ATMPVC) && defined(HAVE_SOCKADDR_ATMPVC)
      case AF_ATMPVC: return sizeof (struct sockaddr_atmpvc);
  #endif
  #if defined(AF_ATMSVC) && defined(HAVE_SOCKADDR_ATMSVC)
      case AF_ATMSVC: return sizeof (struct sockaddr_atmsvc);
  #endif
  #if defined(AF_X25) && defined(HAVE_SOCKADDR_X25)
      case AF_X25: return sizeof (struct sockaddr_x25);
  #endif
  #if defined(AF_ROSE) && defined(HAVE_SOCKADDR_ROSE)
      case AF_ROSE: return sizeof (struct sockaddr_rose);
  #endif
  #if defined(AF_DECnet) && defined(HAVE_SOCKADDR_DN)
      case AF_DECnet: return sizeof (struct sockaddr_dn);
  #endif
  #if defined(AF_PACKET) && defined(HAVE_SOCKADDR_LL)
      case AF_PACKET: return sizeof (struct sockaddr_ll);
  #endif
  #if defined(AF_ASH) && defined(HAVE_SOCKADDR_ASH)
      case AF_ASH: return sizeof (struct sockaddr_ash);
  #endif
  #if defined(AF_ECONET) && defined(HAVE_SOCKADDR_EC)
      case AF_ECONET: return sizeof (struct sockaddr_ec);
  #endif
  #if defined(AF_IRDA) && defined(HAVE_SOCKADDR_IRDA)
      case AF_IRDA: return sizeof (struct sockaddr_irda);
  #endif
  #if defined(AF_LINK) && defined(HAVE_SOCKADDR_DL)
      case AF_LINK: return sizeof (struct sockaddr_dl);
  #endif
    }
  return sizeof (struct sockaddr);
}

static void catch (GError** error, int e)
{
  const guint code = g_io_error_from_errno (e);
  const GQuark domain = G_IO_ERROR;
  const gchar *message = g_strerror (e);

  g_set_error_literal (error, domain, code, message);
}

static AdvNetIfacesInfo** expand (GHashTable* set)
{
  GList* list = NULL;
  GList* link = NULL;
  AdvNetIfacesInfo** array = NULL;
  guint i, length;

  length = g_hash_table_size (set);
  array = g_new0 (AdvNetIfacesInfo*, 1 + length);

  for (link = (list = g_hash_table_get_values (set)), i = 0; i < length; link = link->next, ++i)

    array [i] = link->data;

  g_hash_table_steal_all (set);
  g_hash_table_unref (set);
  g_list_free (list);
  return array;
}

static GSocketAddress* extract_addr (struct sockaddr* addr)
{
  if (addr == NULL || addr->sa_family == AF_UNSPEC)
    return NULL;

  GSocketAddress* address = NULL;
  struct sockaddr* bigaddr = NULL;
  socklen_t length = 0;

  if (SA_LEN (addr) >= af_to_len (addr->sa_family))
    
    length = SA_LEN (addr);
  else
    {
      length = af_to_len (addr->sa_family);
      bigaddr = (gpointer) g_new0 (guint8, length);

      memcpy (bigaddr, addr, SA_LEN (addr));
  #ifdef HAVE_SOCKADDR_SA_LEN
      bigaddr->sa_len = gnilen;
  #endif // HAVE_SOCKADDR_SA_LEN
      addr = bigaddr;
    }

  gpointer data;

  switch (addr->sa_family)
    {
      case AF_INET:
  #ifdef AF_INET6
      case AF_INET6:
  #endif // AF_INET6
        data = (gpointer) addr;
      create_native:
        address = g_socket_address_new_from_native (data, length);
        break;
  #if defined(AF_LINK)
      case AF_LINK:

        length = ((struct sockaddr_dl*) addr)->sdl_alen;
        data = LLADDR (((struct sockaddr_dl*) addr));
        goto create_native;
  #endif // AF_LINK
  #if defined(AF_PACKET)
      case AF_PACKET:

        length = ((struct sockaddr_ll*) addr)->sll_halen;
        data = ((struct sockaddr_ll*) addr)->sll_addr;
        goto create_native;
  #endif // AF_PACKET
      default:

        length -= (sizeof (struct sockaddr) - sizeof (addr->sa_data));
        data = addr->sa_data;
        goto create_native;
    }
  return (_g_free0 (bigaddr), address);
}

#define APPEND_FIELD(var,expr) G_STMT_START { if ((var) == NULL) { var = (expr); } } G_STMT_END

AdvNetIfacesInfo** adv_net_ifaces_enumerate (GSocketFamily family, GError** error)
{
  AdvNetIfacesInfo* info;
  gchar* name;
  GHashTable* set;
#if defined(HAVE_GETIFADDRS)
  struct ifaddrs* addr = NULL;
  struct ifaddrs* addrs = NULL;
  int e;

  const GDestroyNotify dd = (GDestroyNotify) adv_net_ifaces_info_free;

  if ((e = getifaddrs (&addrs)), G_UNLIKELY (e < 0))

    return (catch (error, e), NULL);
  else
    {
      set = g_hash_table_new_full (g_str_hash, g_str_equal, NULL, dd);

      for (addr = addrs; addr; addr = addr->ifa_next) if (addr->ifa_name != NULL)
        {
          if (addr->ifa_addr == NULL || addr->ifa_addr->sa_family != family)

            continue;

          if ((info = g_hash_table_lookup (set, addr->ifa_name)) == NULL)
            {
              name = g_strdup (addr->ifa_name);
              info = g_slice_new0 (AdvNetIfacesInfo);

              g_hash_table_insert (set, info->name = name, info);
            }

          APPEND_FIELD (info->address, extract_addr (addr->ifa_addr));
          APPEND_FIELD (info->netmask, extract_addr (addr->ifa_netmask));

          info->loopback = (addr->ifa_flags & IFF_LOOPBACK) != 0;
          info->ppp = (addr->ifa_flags & IFF_POINTOPOINT) != 0;

          if (addr->ifa_flags & (IFF_POINTOPOINT | IFF_LOOPBACK))

            APPEND_FIELD (info->peer, extract_addr (addr->ifa_dstaddr));
          else
            APPEND_FIELD (info->broadcast, extract_addr (addr->ifa_broadaddr));
        }

      freeifaddrs (addrs);
    }
#elif defined(HAVE_SIOCGIFCONF)
  struct CNAME (ifconf) ifc;
  int len = -1, fd, e;

  if ((fd = socket (AF_INET, SOCK_DGRAM, 0)), G_UNLIKELY (fd < 0))

    return (catch (error, errno), NULL);
  else
    {

    # if HAVE_SIOCGSIZIFCONF
      if (ioctl (fd, SIOCGSIZIFCONF, &len) < 0)
        len = -1;
    # elif HAVE_SIOCGLIFNUM
      G_STMT_START {

        struct lifnum lifn = {0};
        lifn.lifn_family = AF_UNSPEC;
        lifn.lifn_flags = LIFC_NOXMIT | LIFC_TEMPORARY | LIFC_ALLZONES;
        ifc.lifc_family = AF_UNSPEC;
        ifc.lifc_flags = LIFC_NOXMIT | LIFC_TEMPORARY | LIFC_ALLZONES;

        len = ioctl (fd, SIOCGLIFNUM, (char*) &lifn) < 0 ? -1 : lifn.lifn_count;s
      } G_STMT_END;
    # endif // HAVE_SIOCGLIFNUM

      len = len < 0 ? 64 : len;

      ifc. CNAME (ifc_len) = (int) (len * sizeof (struct CNAME (ifreq)));
      ifc. CNAME (ifc_buf) = g_malloc (ifc. CNAME (ifc_len));

    # ifdef HAVE_SIOCGLIFNUM
      if ((e = ioctl (fd, SIOCGLIFCONF, &ifc)), G_UNLIKELY (e < 0))
    # else // !HAVE_SIOCGLIFNUM
      if ((e = ioctl (fd, SIOCGIFCONF, &ifc)), G_UNLIKELY (e < 0))
    # endif // HAVE_SIOCGLIFNUM
        {
          g_close (fd, NULL);
          g_free (ifc. CNAME (ifc_req));
          return (catch (error, e), NULL);
        }
      else
        {
          struct CNAME (ifreq) ifr;
          struct CNAME (ifreq)* pfreq = ifc. CNAME (ifc_req);
          struct CNAME (ifreq)* pfreqend = G_STRUCT_MEMBER_P (pfreq, ifc.CNAME (ifc_len));
          gboolean is_p2p = FALSE;

          set = g_hash_table_new_full (g_str_hash, g_str_equal, g_free, NULL);

          while (pfreq < pfreqend)
            {
              if (pfreq->CNAME (ifr_addr).sa_family == (sa_family_t) family)
                {
                  if ((info = g_hash_table_lookup (set, pfreq->CNAME (ifr_name))) == NULL)
                    {
                      name = g_strdup (pfreq->CNAME (ifr_name));
                      info = g_slice_new0 (AdvNetIfacesInfo);

                      g_hash_table_insert (set, info->name = name, info);
                    }

                  APPEND_FIELD (info->address, extract_addr (&pfreq->CNAME (ifr_addr)));

                  strncpy (ifr.CNAME (ifr_name), pfreq->CNAME (ifr_name), IFNAMSIZ);

                  /* netmask */
                  # ifdef HAVE_SIOCGIFNETMASK
                  # ifdef HAVE_SIOCGLIFNUM
                    if (ioctl (fd, SIOCGLIFNETMASK, &ifr) == 0)
                  # else // HAVE_SIOCGLIFNUM
                    if (ioctl (fd, SIOCGIFNETMASK, &ifr) == 0)
                  # endif // HAVE_SIOCGLIFNUM
                      APPEND_FIELD (info->netmask, extract_addr (& ifr.CNAME (ifr_netmask)));
                  # endif // HAVE_SIOCGIFNETMASK

                  /* flags */
                  # ifdef HAVE_SIOCGIFFLAGS
                  # ifdef HAVE_SIOCGLIFNUM
                    if (ioctl (fd, SIOCGLIFFLAGS, &ifr) == 0)
                  # else // HAVE_SIOCGLIFNUM
                    if (ioctl (fd, SIOCGIFFLAGS, &ifr) == 0)
                  # endif // HAVE_SIOCGLIFNUM
                      {
                        is_p2p =
                        (info->loopback = (ifr.CNAME (ifr_flags) & IFF_LOOPBACK) != 0) ||
                        (info->ppp = (ifr.CNAME (ifr_flags) & IFF_POINTOPOINT) != 0);
                      }
                  # endif // HAVE_SIOCGIFFLAGS

                    if (is_p2p)
                      {
                  # ifdef HAVE_SIOCGIFDSTADDR
                  # ifdef HAVE_SIOCGLIFNUM
                        if (ioctl (fd, SIOCGLIFDSTADDR, &ifr) == 0)
                  # else // HAVE_SIOCGLIFNUM
                        if (ioctl (fd, SIOCGIFDSTADDR, &ifr) == 0)
                  # endif // HAVE_SIOCGLIFNUM
                          APPEND_FIELD (info->peer, extract_addr (& ifr.CNAME (ifr_dstaddr)));
                  # endif // HAVE_SIOCGIFDSTADDR
                      }
                    else
                      {
                  # ifdef HAVE_SIOCGIFBRDADDR
                  # ifdef HAVE_SIOCGLIFNUM
                        if (ioctl (fd, SIOCGLIFBRDADDR, &ifr) == 0)
                  # else // HAVE_SIOCGLIFNUM
                        if (ioctl (fd, SIOCGIFBRDADDR, &ifr) == 0)
                  # endif // HAVE_SIOCGLIFNUM
                          APPEND_FIELD (info->broadcast, extract_addr (& ifr.CNAME (ifr_broadaddr)));
                  # endif // HAVE_SIOCGIFBRDADDR
                      }
                }

            /* ++i */
            # ifndef HAVE_SOCKADDR_SA_LEN
              ++pfreq;
            # else // HAVE_SOCKADDR_SA_LEN
              /* On some platforms, the ifreq struct can *grow*(!) if the socket address
                 is very long. Mac OS X is such a platform. */
              G_STMT_START {
                size_t len = sizeof (struct CNAME (ifreq));
                if (pfreq->ifr_addr.sa_len > sizeof (struct sockaddr))
                  len = len - sizeof (struct sockaddr) + pfreq->ifr_addr.sa_len;
                pfreq = G_STRUCT_MEMBER_P (pfreq, len);
              } G_STMT_END;
            # endif // !HAVE_SOCKADDR_SA_LEN
            }

          g_close (fd, NULL);
          g_free (ifc. CNAME (ifc_req));
        }
    }
#endif // HAVE_SIOCGIFCONF
  return set == NULL ? NULL : expand (set);
}
