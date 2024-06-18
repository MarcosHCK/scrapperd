/* Copyright 2024-2029
 * This file is part of ScrapperD.
 *
 * ScrapperD is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * ScrapperD is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with ScrapperD. If not, see <http://www.gnu.org/licenses/>.
 */

[CCode (cprefix = "KDBus", lower_case_cprefix = "kdbus_")]

namespace KademliaDBus
{
  internal class NodeSkeleton : GLib.Object, KademliaDBus.Node
    {
      public string[] public_addresses { get; construct; }
      public string[] roles { get; construct; }

      public string[] PublicAddresses { owned get { return public_addresses; } }
      public string[] Roles { owned get { return roles; } }

      public NodeSkeleton (string[] public_addresses, string[] roles)
        {
          Object (public_addresses : public_addresses, roles : roles);
        }

      public async bool Ping () throws GLib.Error
        {
          return true;
        }
    }

  internal class NodeRoleSkeleton : GLib.Object, KademliaDBus.NodeRole
    {
      public Peer peer { get; construct; }
      public override uint8[] Id { owned get { return peer.id.bytes.copy (); } }

      public NodeRoleSkeleton (Peer peer)
        {
          Object (peer : peer);
        }
    }
}
