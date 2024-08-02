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

tests = \
  [
    { 'description' : 'Advertise library', 'files' : [ 'advertise.vala' ], 'libs' : [ libadvertise ],
      'deps' : [ libjson_glib_dep, libjson_glib_vapi ] },
    { 'description' : 'Krypt BC implementation', 'files' : [ 'bcproto.vala' ], 'libs' : [ libkrypt ] },
    { 'description' : 'Krypt ECDHE implementation', 'files' : [ 'dhproto.vala' ], 'libs' : [ libkrypt ] },
    { 'description' : 'Krypt stream implementation', 'files' : [ 'krypt.vala' ], 'libs' : [ libkrypt ] },
    { 'description' : 'Kademlia buckets tests', 'files' : [ 'buckets.vala' ], 'libs' : [ libkademlia ] },
    { 'description' : 'Kademlia DBus hub tests', 'files' : [ 'hub.vala', 'baseintegration.vala' ], 'libs' : [ libgvalr, libkademlia, libkademlia_dbus ] },
    { 'description' : 'Kademlia integration tests', 'files' : [ 'integration.vala', 'baseintegration.vala' ], 'libs' : [ libgvalr, libkademlia ] },
    { 'description' : 'Kademlia key tests', 'files' : [ 'key.vala' ], 'libs' : [ libkademlia ] },
  ]

foreach test_ : tests

  deps = test_.get ('deps', [ ])
  description = test_.get ('description')
  files = test_.get ('files')
  libs = test_.get ('libs', [ ])

  assert (files.length () > 0)

  test \
    (
      description,

      executable \
        (
          '@0@.test'.format (files.get (0)),

          dependencies : libglib_vapis + \
            [
              libgio_dep, libglib_dep, libgobject_dep
            ] + deps,

          include_directories : [ configdir ] + libdirs,

          link_with : libs,

          sources : files + [ 'base.vala' ],
        ),

      env :
        [
          'G_TEST_SRCDIR=@0@'.format(meson.current_source_dir () / '..'),
          'G_TEST_BUILDDIR=@0@'.format(meson.current_build_dir () / '..'),
        ],
    )
endforeach
