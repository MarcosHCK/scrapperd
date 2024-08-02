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

libsoup_dep = dependency ('libsoup-3.0', required : true)
libsoup_vapi = vala.find_library ('libsoup-3.0')

executable \
  (
    'scrapperd-scrapper',

    dependencies : libglib_vapis + \
      [
        libgio_dep, libglib_dep, libgobject_dep,
        libsoup_dep, libsoup_vapi,
      ],

    include_directories : [ configdir ] + libdirs,

    link_with : [ libkademlia, libkademlia_dbus, libscrapperd ],

    sources :
      [
        'application.vala',
        'linksearcher.vala',
        'scrapper.vala',
        'store.vala',
      ],
  )
