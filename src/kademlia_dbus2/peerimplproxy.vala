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
      private int64 age = 0;
      [CCode (cheader_filename = "glib.h", cname = "G_USEC_PER_SEC")]
      public extern const int64 USEC_PER_SEC;
      public const int64 FRESHTIME = 3 * USEC_PER_SEC;

      public PeerImplProxy (AddressProvider address_provider, Key? id, AddressRegistry address_registry, RoleProvider role_provider, RoleRegistry role_registry)
        {
          Object (address_provider : address_provider, address_registry : address_registry, id : id, role_provider : role_provider, role_registry : role_registry, value_store : new DummyValueStore ());
        }

      protected override PeerRef get_self ()
        {
          return PeerRef.anonymous (id.bytes);
        }

      public new async bool join (Key to, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var done = yield ((PeerImpl) this).join (to, cancellable);
          age = GLib.get_monotonic_time ();
          return done;
        }

      public override GLib.SList<Key> nearest (Key id)
        {
          var list = base.nearest (id);
          list.foreach (a => { if (Key.equal (a, this.id)) list.remove (a); });
          return (owned) list;
        }

      public async bool refresh (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          if ((GLib.get_monotonic_time () - age) > FRESHTIME)
            {
              debug ("refreshing proxy %s", id.to_string ());

              yield lookup_node (id, cancellable);
              age = GLib.get_monotonic_time ();
            }

          return true;
        }
    }
}
