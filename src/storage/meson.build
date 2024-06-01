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

gnome = import ('gnome')

libkademlia = library \
  (
    'kademlia',

    dependencies :
      [
        libgio_dep,
        libglib_dep,
        libgobject_dep,
      ],

    include_directories :
      [
        configdir,
        include_directories ('.'),
      ],

    sources :
      [
        'bucket.c',
        'bucket.h',
        'kademlia.h',
        'key.c',
        'key.h',
        'node.c',
        'node.h',
        'value.c',
        'value.h',

        gnome.genmarshal ('node.signals', sources : [ 'node.signals' ])
      ]
  )

libstorage = library \
  (
    'storage',

    dependencies :
      [
        vala.find_library ('gio-2.0'),
        vala.find_library ('glib-2.0'),
        vala.find_library ('gobject-2.0'),

        libgio_dep,
        libglib_dep,
        libgobject_dep,
      ],

    include_directories :
      [
        configdir,
        libscrapperdinc,

        include_directories ('.'),
      ],

    link_with : [ libkademlia, libscrapperd ],

    sources :
      [
        'kademlia.vapi',
        'storage.vala',
      ],
  )

storagemod = shared_module \
  (
    'storagemod',

    dependencies :
      [
        vala.find_library ('gio-2.0'),
        vala.find_library ('glib-2.0'),
        vala.find_library ('gobject-2.0'),

        libgio_dep,
        libglib_dep,
        libgobject_dep,
      ],

    include_directories : [ configdir, libscrapperdinc ],

    link_with : [ libkademlia, libstorage, libscrapperd ],

    sources :
      [
        'kademlia.vapi',
        'instance.vala',
      ]
  )
