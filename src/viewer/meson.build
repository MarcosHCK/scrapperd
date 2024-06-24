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
libgtk_dep = dependency ('gtk4')

executable \
  (
    'scrapperd-viewer',

    dependencies :
      [
        vala.find_library ('gio-2.0'), libgio_dep,
        vala.find_library ('glib-2.0'), libglib_dep,
        vala.find_library ('gobject-2.0'), libgobject_dep,
        vala.find_library ('gtk4'), libgtk_dep,
      ],

    c_args : [ '-DGETTEXT_PACKAGE=@0@'.format (default_defines ['G_LOG_DOMAIN']) ],

    include_directories : [ configdir, libsdir ],

    link_with : [ libkademlia, libkademlia_dbus, libscrapperd ],

    sources :
      [
        'application.vala',
        'applicationwindow.vala',
        'infobar.vala',
        'infobarmessage.vala',
        'joindialog.vala',
        'role.vala',
        'rolerow.vala',

        gnome.compile_resources ('resources', 'resources.xml'),
      ],
  )
