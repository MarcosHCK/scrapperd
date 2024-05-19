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

project \
  (
    'scrapperd', 'c', 'vala',

    default_options : [ 'warning_level=3' ],
    meson_version : '>= 1.2',

    version : '@0@.@1@.@2@'.format \
      (
        run_command ('git', 'describe', check : true).stdout ().strip ().split ('-').get (0).split ('.').get (0).substring (1),
        run_command ('git', 'describe', check : true).stdout ().strip ().split ('-').get (0).split ('.').get (1),
        run_command ('git', 'describe', check : true).stdout ().strip ().split ('-').get (0).split ('.').get (2),
      ),
  )

cc = meson.get_compiler ('c')
vala = meson.get_compiler ('vala')

########################
# Extract version info #
########################

git_version = run_command ('git', 'describe', check : true).stdout ().strip ()
git_version_list = git_version.split ('-')
git_version_list2 = git_version_list.get (0).split ('.')
git_version_stage = git_version_list.get (1)
git_version_major = git_version_list2.get (0).substring (1)
git_version_minor = git_version_list2.get (1)
git_version_micro = git_version_list2.get (2)

########################
# Configuration begins #
########################

configdir = include_directories ('.')
configh = configuration_data ()

configh.set ('DEBUG', get_option ('debug').to_int ())
configh.set ('DEVELOPER', get_option ('developer').to_int ())
configh.set_quoted ('PACKAGE_BUGREPORT', 'nouser@nohost.com')
configh.set_quoted ('PACKAGE_NAME', meson.project_name ())
configh.set_quoted ('PACKAGE_STRING', '@0@ @1@'.format (meson.project_name (), git_version))
configh.set_quoted ('PACKAGE_TARNAME', meson.project_name ())
configh.set_quoted ('PACKAGE_URL', 'https://github.com/MarcosHCK/ScrapperD')
configh.set_quoted ('PACKAGE_VERSION', git_version)
configh.set ('PACKAGE_VERSION_MAJOR', git_version_major)
configh.set ('PACKAGE_VERSION_MINOR', git_version_minor)
configh.set ('PACKAGE_VERSION_MICRO', git_version_micro)
configh.set_quoted ('PACKAGE_VERSION_STAGE', git_version_stage)

# Global defines

default_defines = \
  {
    'G_LOG_DOMAIN' : '"ScrapperD"',
    'G_LOG_USE_STRUCTURED' : '1',
  }

foreach name, value : default_defines

  add_project_arguments (cc.get_supported_arguments ('-D@0@=@1@'.format (name, value)), language : 'c')
  configh.set (name, value)
endforeach

add_project_arguments ([ '--pkg', 'config' ], language : 'vala')
add_project_arguments ([ '--vapidir', meson.project_source_root () / 'src' / 'vapi' ], language: 'vala')
add_project_arguments ((get_option ('debug') == false ? [] : [ '-D', 'DEBUG' ]), language : 'vala')
add_project_arguments ((get_option ('developer') == false ? [] : [ '-D', 'DEVELOPER' ]), language : 'vala')
configure_file (output : 'config.h', configuration : configh)

########################
# Dependencies         #
########################

libgio_dep = dependency ('gio-2.0', required : true)
libglib_dep = dependency ('glib-2.0', required : true)
libgobject_dep = dependency ('gobject-2.0', required : true)

subdir ('src')

########################
# Summaries            #
########################

summary \
  (
    {
      'C compiler' : cc.get_id (),
      'Vala compiler' : vala.get_id (),
      'debug build' : get_option ('debug') ? 'yes' : 'no',
      'develop build' : get_option ('developer') ? 'yes' : 'no',
      'host cpu' : host_machine.cpu_family (),
      'host endian' : host_machine.endian (),
      'host system' : host_machine.system (),
    },
   section: 'Build environment'
  )

if build_machine.system () != host_machine.system ()
  summary \
    (
      {
        'build cpu' : build_machine.cpu_family (),
        'build endian' : build_machine.endian (),
        'build system' : build_machine.system (),
      },
     section: 'Build environment'
    )
endif
