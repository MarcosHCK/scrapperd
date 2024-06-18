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
  [DBus (name = "org.hck.kademlia.Node")]

  public interface Node : GLib.Object
    {
      public const string BASE_PATH = "/org/hck/Kademlia";

      public abstract string[] PublicAddresses { owned get; }
      public abstract string[] Roles { owned get; }

      public abstract async bool Ping () throws GLib.Error;
    }

  [DBus (name = "org.hck.kademlia.NodeRole")]

  public interface NodeRole : GLib.Object
    {
      public abstract uint8[] Id { owned get; }
    }
}
