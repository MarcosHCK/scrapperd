#! /usr/bin/env python3
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
from argparse import ArgumentParser
from os import getenv
from subprocess import run, Popen, PIPE, STDOUT
import re

def git_describe (pre_args: None | list[str] = None, *args):

  arg = [ 'git', *(pre_args or []), 'describe', '--always', '--dirty', *args ]
  git = Popen (arg, executable = 'git', text = True, stderr = PIPE, stdout = PIPE)
  ver = git.communicate ()
  ver = list ([ None if not out else out.strip ('\r\n') for out in ver ])

  if git.returncode != 0: raise Exception (ver [1])
  return ver [0]

def meson_rewrite (*args):

  rewrite = getenv ('MESONREWRITE') or 'meson rewrite'
  sourcedir = getenv ('MESON_PROJECT_DIST_ROOT')

  if sourcedir == None:

    raise Exception ('not set')

  arg = rewrite.split (' ')
  bin = arg [0]
  arg = [ *arg, '--sourcedir', sourcedir, *args ]

  proc = Popen (arg, executable = bin, text = True, stderr = PIPE)
  out = proc.communicate ()
  out = list ([ None if not val else val.strip ('\r\n') for val in out ])

  if proc.returncode != 0: raise Exception (out [1])
  return True

def program ():

  parser = ArgumentParser ()

  parser.add_argument ('type', choices = [ 'get-version', 'get-version-bits', 'set-dist' ], type = str)
  parser.add_argument ('arguments', nargs = '*', type = str)

  args = parser.parse_args ()
  root = getenv ('MESON_SOURCE_ROOT') or '.'

  match (args.type):

    case 'get-version':

      if (ver := git_describe (pre_args = [ '-C', root ])).startswith ('v'):
        ver = ver [1:]

      print (ver)

    case 'get-version-bits':

      if (ver := git_describe (pre_args = [ '-C', root ])).startswith ('v'):
        ver = ver [1:]

      print (ver.split ('-') [0])

    case 'set-dist':

      meson_rewrite ('kwargs', 'set', 'project', '/', 'version', args.arguments [0])

program ()
