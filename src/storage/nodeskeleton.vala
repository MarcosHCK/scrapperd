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
using Kademlia;

[CCode (cprefix = "Scrapperd", lower_case_cprefix = "scrapperd_")]

namespace ScrapperD
{
  public class StorageNodeSkeleton : GLib.Object, StorageNode
    {
      public Peer peer { get; construct; }

      public StorageNodeSkeleton (Peer peer)
        {
          Object (peer : peer);
        }

      public async Neighbor[] find_node (uint8[] key, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var id = new Key.verbatim (key);
          return (owned) Value.delegated (peer.nearest (id)).neighbors;
        }

      public async Value find_value (uint8[] key, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var id = new Key.verbatim (key);
          var value = (GLib.Value?) null;

          if ((value = yield peer.lookup (id)) == null)

            return Value.delegated (peer.nearest (id));
          else
            return Value.inmediate (value);
        }

      public async bool store (uint8[] key, uint8[] value, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          yield peer.insert (new Key.verbatim (key), new GLib.Bytes (value));
          return false;
        }

      public async bool ping (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          return true;
        }
    }
}
