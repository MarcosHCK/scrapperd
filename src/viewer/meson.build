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
libgtk_vapi = vala.find_library ('gtk4')

scrapperd_viewer_support = library \
  (
    'scrapperd-viewer',

    dependencies : libglib_vapis + \
      [
        libgio_dep, libglib_dep, libgobject_dep,
      ],

    include_directories : [ configdir ] + libdirs,

    link_with : [ libkademlia, libkademlia_dbus ],

    sources :
      [
        'role.vala',
        'rolesource.vala',
        'roletarget.vala',
        'roletransport.vala',
      ],
  )

executable \
  (
    'scrapperd-viewer',

    dependencies : libglib_vapis + \
      [
        libgio_dep, libglib_dep, libgobject_dep,
        libgtk_dep, libgtk_vapi,
        libjson_glib_dep, libjson_glib_vapi,
      ],

    c_args : [ '-DGETTEXT_PACKAGE=@0@'.format (default_defines ['G_LOG_DOMAIN']) ],

    include_directories : [ configdir ] + libdirs,

    link_with : [ libadvertise, libkademlia, libkademlia_ad, libkademlia_dbus, scrapperd_viewer_support ],

    sources :
      [
        'adrow.vala',
        'application.vala',
        'applicationwindow.vala',
        'infobar.vala',
        'infobarmessage.vala',
        'joindialog.vala',
        'rolerow.vala',

        gnome.compile_resources ('resources', 'resources.xml'),
      ],
  )
