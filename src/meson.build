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

libdirs = []

libgio_vapi = vala.find_library ('gio-2.0')
libglib_vapi = vala.find_library ('glib-2.0')
libgobject_vapi = vala.find_library ('gobject-2.0')

libglib_vapis = [ libgio_vapi, libglib_vapi, libgobject_vapi ]

private_bindir = get_option ('libexecdir') / 'scrapperd'
private_libdir = get_option ('libdir') / 'scrapperd'

subdir ('kademlia')

subdir ('gvalr')
subdir ('krypt')
subdir ('netdis')

subdir ('kademlia_dbus')

subdir ('advertise')
subdir ('kademlia_ad')

subdir ('application')

if get_option ('scrapper').enabled ()

  subdir ('scrapper')
else
  libsoup_dep = disabler ()
  libsoup_vapi = disabler ()
  libscrapping = disabler ()
endif

if get_option ('storage').enabled ()
  subdir ('storage')
endif

if get_option ('viewer').enabled ()
  subdir ('viewer')
endif

subdir ('tests')
