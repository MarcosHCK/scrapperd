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

[CCode (cprefix = "KDBus", lower_case_cprefix = "k_dbus_")]

namespace Kademlia.DBus
{
  private class DummyValueStore : GLib.Object, ValueStore
    {
      public async bool insert_value (Key id, GLib.Value? value = null, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          throw new PeerError.UNREACHABLE ("anonymous node");
        }

      public async GLib.Value? lookup_value (Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          throw new PeerError.UNREACHABLE ("anonymous node");
        }
    }

  internal class PeerImplProxy : PeerImpl
    {

      public PeerImplProxy (Hub hub, string role, Key? id = null)
        {
          base (new DummyValueStore (), id);
          this.hub = hub;
        }

      protected override PeerRef get_self ()
        {
          return PeerRef.anonymous (id.bytes);
        }

      public override GLib.SList<Key> nearest (Key id)
        {
          var list = base.nearest (id);
          list.foreach (a => { if (Key.equal (a, this.id)) list.remove (a); });
          return (owned) list;
        }
    }
}
