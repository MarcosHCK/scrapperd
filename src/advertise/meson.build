# Copyright 2024-2029
# This file is part of ScrapperD.
#
# ScrapperD is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ScrapperD is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ScrapperD. If not, see <http://www.gnu.org/licenses/>.
#

libjson_glib_dep = dependency ('json-glib-1.0', required : true)
libjson_glib_vapi = vala.find_library ('json-glib-1.0')

netconf = configuration_data ()

if true

  sockaddr_includes = \
    [
      'net/if_dl.h', 'netash/ash.h',
      'netatalk/at.h', 'netax25/ax25.h',
      'neteconet/ec.h', 'netipx/ipx.h',
      'netpacket/packet.h', 'netrose/rose.h',
      'linux/irda.h', 'linux/atm.h',
      'linux/llc.h', 'linux/tipc.h',
      'linux/dn.h',
    ]

  sockaddr_suffixes = \
    [
      'at', 'ax25', 'dl', 'eon', 'in', 'in6',
      'inarp', 'ipx', 'iso', 'ns', 'un', 'x25',
      'rose', 'ash', 'ec', 'll', 'atmpvc', 'atmsvc',
      'dn', 'irda', 'llc',
    ]

  sio_macros = \
    [
      'SIOCGIFADDR',
      'SIOCGIFBRDADDR',
      'SIOCGIFCONF',
      'SIOCGIFDSTADDR',
      'SIOCGIFFLAGS',
      'SIOCGIFHWADDR',
      'SIOCGIFNETMASK',
      'SIOCGLIFCONF',
      'SIOCGLIFFLAGS',
      'SIOCGLIFNUM',
      'SIOCGSIZIFCONF',
    ]

  socket_includes = \
    [
      '#include <sys/types.h>',
      '#include <sys/socket.h>',
      '#include <sys/ioctl.h>',
      '#include <net/if.h>',
    ] \
 \
  + (cc.check_header ('netinet/in.h') == false ? [] : '#include <netinet/in.h>') \
  + (cc.check_header ('netinet/in_var.h') == false ? [] : '#include <netinet/in_var.h>') \
  + \
    [
      '#include <arpa/inet.h>',
    ]

  if target_machine.system ().startswith ('sunos')

    socket_includes += \
      [
        '#include <unistd.h>',
        '#include <stropts.h>',
        '#include <sys/sockio.h>',
      ]
  endif

  foreach include : sockaddr_includes

    varname = 'HAVE_@0@'.format (include.to_upper ().replace ('.', '_').replace ('/', '_'))
    value = cc.check_header (include)
    netconf.set (varname, value)
    socket_includes += value == false ? [] : [ '#include <@0@>'.format (include) ]
  endforeach

  foreach suffix : sockaddr_suffixes

    varname = 'HAVE_SOCKADDR_@0@'.format (suffix.to_upper ())
    value = cc.has_type ('struct sockaddr_@0@'.format (suffix), prefix : socket_includes)
    netconf.set (varname, value)
  endforeach

  any_sio = false

  foreach sio_macro : sio_macros

    varname = 'HAVE_@0@'.format (sio_macro)
    value = cc.has_define (sio_macro, prefix : socket_includes)
    netconf.set (varname, value)
    any_sio = any_sio or value
  endforeach

  if true

    has_ifaddres = cc.check_header ('ifaddrs.h')
    use_getifaddrs = cc.has_function ('getifaddrs')
    has_sockaddrsalen = cc.has_member ('struct sockaddr', 'sa_len', prefix : socket_includes)
    has_sockaddrin6 = cc.has_type ('struct sockaddr_in6', prefix : socket_includes)

    netconf.set ('HAVE_GETIFADDRS', use_getifaddrs)
    netconf.set ('HAVE_IFADDRS', has_ifaddres)
    netconf.set ('HAVE_SOCKET_IOCTLS', any_sio)
    netconf.set ('HAVE_SOCKADDR_SA_LEN', has_sockaddrsalen)
    netconf.set ('HAVE_SOCKADDRIN6', has_sockaddrin6)
  endif
endif

libadvertise = library \
  (
    'advertise',

    dependencies : libglib_vapis + \
      [
        libgio_dep, libglib_dep, libgobject_dep, libjson_glib_dep,
        libjson_glib_vapi,
      ],

    include_directories : [ configdir ] + libdirs,

    sources :
      [
        'channel.vala',
        'clock.vala',
        'hub.vala',
        'ipv4channel.h',
        'ipv4channel.vala',
        'netifaces.c',
        'netifaces.h',
        'netifaces.vapi',
        'peeker.vala',
        'protocol.vala',

        configure_file (configuration : netconf, output : 'netconf.h'),
      ]
  )

libdirs += include_directories ('.')
