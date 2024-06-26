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

[CCode (cprefix = "KDBus", lower_case_cprefix = "kdbus_")]

namespace KademliaDBus
{
  internal class DummyValueStore : GLib.Object, ValueStore
    {
      public override async bool insert_value (Key id, GLib.Value? value = null, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          throw new PeerError.UNREACHABLE ("anonymous node");
        }

      public override async GLib.Value? lookup_value (Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          throw new PeerError.UNREACHABLE ("anonymous node");
        }
    }

  public sealed class PeerImplProxy : PeerImpl
    {

      public PeerImplProxy (string role)
        {
          base (role, new DummyValueStore ());
        }

      protected override ValueNode.PeerRef get_self ()
        {
          return ValueNode.PeerRef.anonymous (id.bytes);
        }
    }
}
