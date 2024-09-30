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

libkademlia_dbus2 = library \
  (
    'kademlia_dbus2',

    dependencies : libglib_vapis +
      [
        libgio_dep, libglib_dep,
        libgvalr_dep, libnetdis_dep
      ],

    include_directories : libdirs + [ configdir ],
    install : true,

    link_with : [ libkademlia, libkrypt ],

    sources :
      [
        'addressprovider.vala',
        'addressregistry.vala',
        'addressservice.vala',
        'clock.vala',
        'hub.vala',
        'localprovider.vala',
        'localregistry.vala',
        'node.vala',
        'nodeskeleton.vala',
        'peerimpl.vala',
        'peerimplproxy.vala',
        'refs.vala',
        'roleprovider.vala',
        'roleregistry.vala',
        'roleservice.vala',
        'socketroleservice.vala',
      ]
  )

libdirs += include_directories ('.')
