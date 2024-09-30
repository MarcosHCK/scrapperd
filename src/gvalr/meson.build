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

libgvalr = library \
  (
    'gvalr',

    dependencies : [ libglib_dep, libgobject_dep ],
    include_directories : [ configdir ],
    install : true,
    sources : [ 'gvalr.h', 'nat2net.c', 'net2nat.c' ]
  )

libgvalr_dep = declare_dependency \
  (
    include_directories : [ include_directories ('.') ],
    link_with : [ libgvalr ],
    sources : [ 'gvalr.h', 'gvalr.vapi' ],
  )
