#! /bin/sh
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
BUILDDIR=builddir
NETNAME=kademlia-net

network_kill ()
{
  running=$(docker ps -qf ancestor=scrapperd:latest)
  chars=$(docker ps -qf ancestor=scrapperd:latest | wc -l)

  if [ $((chars)) -gt 0 ]; then

    docker container kill $running
  fi
}

case $1 in

  build-*)
      if [[ "" = "$(find "$BUILDDIR/meson-dist/" -maxdepth 1 -name "*.tar.xz")" ]]
      then
        echo "Must generate dist source package"
        exit 1
      else
        case $1 in
          build-devel)
            docker build -f Dockerfile.devel -t scrapperd .
            ;;
          build-release)
            docker build -f Dockerfile.release -t scrapperd .
            ;;
        esac
      fi
    ;;

  dist)
      mkdir -p $BUILDDIR/
      meson dist -C $BUILDDIR/
    ;;

  network-add-*)
      instance=`echo "$1" | sed s/network-add-//`
      docker run -dit -e G_MESSAGES_DEBUG=ScrapperD --entrypoint "/libexec/scrapperd/$instance" --network=$NETNAME --rm scrapperd
    ;;

  network-run-*)

      instance=`echo "$1" | sed s/network-run-//`

      case $instance in

        viewer)
          xhost +local:root
          docker run -it -e DISPLAY=$DISPLAY -e G_MESSAGES_DEBUG=ScrapperD -v /tmp/.X11-unix:/tmp/.X11-unix --entrypoint "/libexec/scrapperd/$instance" --network=$NETNAME --rm scrapperd
          xhost -local:root
          ;;
        *)
          docker run -it -e G_MESSAGES_DEBUG=ScrapperD --entrypoint "/libexec/scrapperd/$instance" --network=$NETNAME --rm scrapperd
          ;;
      esac
    ;;

  network-down)
      network_kill
      docker network rm $NETNAME
    ;;

  network-kill)
      network_kill
    ;;

  network-up)
      docker network create -d bridge $NETNAME --ipv6 --subnet fd00:abcd:1234::/64
    ;;

  network-view)
      docker network inspect $NETNAME
    ;;

  *)
    echo "docker <build-devel|build-release|dist|network-add|network-down|network-kill|network-up>"
    exit 1
    ;;
esac
