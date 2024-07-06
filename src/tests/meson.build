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
  {
    'Kademlia buckets tests' : [ 'buckets.vala' ],
    'Kademlia DBus hub tests' : [ 'hub.vala', 'baseintegration.vala' ],
    'Kademlia integration tests' : [ 'integration.vala', 'baseintegration.vala' ],
    'Kademlia key tests' : [ 'key.vala' ],
    #'Kademlia stress tests' : [ 'stress.vala' ],
  }

foreach description, files : tests

  assert (files.length () > 0)

  file = files.get (0)

  test \
    (
      description,

      executable \
        (
          '@0@.test'.format (file),

          dependencies : [
              vala.find_library ('gio-2.0'), libgio_dep,
              vala.find_library ('glib-2.0'), libglib_dep,
              vala.find_library ('gobject-2.0'), libgobject_dep,
            ],

          include_directories : [ configdir, include_directories ('..') ],

          link_with : [ libscrapperd, libkademlia, libkademlia_dbus ],

          sources : files + [ 'base.vala' ],
        ),

      env :
        [
          'G_TEST_SRCDIR=@0@'.format(meson.current_source_dir () / '..'),
          'G_TEST_BUILDDIR=@0@'.format(meson.current_build_dir () / '..'),
        ],
    )
endforeach
