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

libkademlia = library \
  (
    'kademlia',

    dependencies : libglib_vapis + \
      [
        libgio_dep, libglib_dep, libgobject_dep
      ],

    include_directories : [ configdir ] + libdirs,

    sources :
      [
        'bucket.h',
        'bucket.vapi',
        'buckets.vala',
        'crawler.vala',
        'insertvalue.vala',
        'key.vala',
        'keytypes.h',
        'keyval.h',
        'keyval.vapi',
        'lookupnode.vala',
        'lookupvalue.vala',
        'runner.h',
        'runner.vapi',
        'peer.vala',
        'value.vala',
        'valuepeer.vala',
        'valuestore.vala',
      ],
  )

libdirs += include_directories ('.')
