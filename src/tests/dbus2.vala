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
using Kademlia.DBus;

namespace Testing
{
  public static int main (string[] args)
    {
      GLib.Test.init (ref args, null);
      GLib.Test.add_func (TESTPATHROOT + "/Hub/connect", () => (new TestIntegrationConnect (new TestHub ())).run ());
      GLib.Test.add_func (TESTPATHROOT + "/Hub/insert", () => (new TestIntegrationInsert (new TestHub ())).run ());
      GLib.Test.add_func (TESTPATHROOT + "/Hub/insert_exotic", () => (new TestIntegrationInsertExotic (new TestHub ())).run ());
      GLib.Test.add_func (TESTPATHROOT + "/Hub/lookup", () => (new TestIntegrationLookup (new TestHub ())).run ());
      GLib.Test.add_func (TESTPATHROOT + "/Hub/lookup_node", () => (new TestIntegrationLookupNode (new TestHub ())).run ());
      GLib.Test.add_func (TESTPATHROOT + "/Hub/new", () => new TestHub ());
      return GLib.Test.run ();
    }

  public class TestHub : Hub, PeerProvider
    {

      class DummyRoleService : RoleService
        {
          public DummyRoleService (AddressService address_service)
            {
              Object (address_service : address_service);
            }

          public override async Kademlia.DBus.Node? reach (Address? address, GLib.Cancellable? cancellable = null) throws GLib.Error
            {
              throw new PeerError.UNREACHABLE ("offline RoleService");
            }
        }

      public TestHub (int min_nodes = 100, int max_nodes = 1000)
        {
          var address_service = new AddressService ();
          var role_service = new DummyRoleService (address_service);

          Object (address_service : address_service, role_service : role_service);

          unowned AddressProvider address_provider = address_service;
          unowned AddressRegistry address_registry = address_service;
          unowned LocalRegistry local_registry = role_service;
          unowned RoleProvider role_provider = role_service;
          unowned RoleRegistry role_registry = role_service;

          for (unowned var i = 0; i < GLib.Test.rand_int_range (min_nodes, max_nodes); ++i)
            {
              var id = new Key.random ();
              var value_store = new DummyValueStore ();
              var value_peer = new PeerImpl (address_provider, id, address_registry, role_provider, role_registry, value_store);

              local_registry.add ("testing", value_peer);
            }
        }

      public GLib.List<unowned ValuePeer> list_peers ()
        {
          var list = new GLib.List<unowned ValuePeer> ();
          try { role_service.foreach_local ((i, r, p) => list.append (p)); } catch (GLib.Error e)
            {
              assert_no_error (e);
            }
          return (owned) list;
        }

      public GLib.List<unowned Key> list_peers_id ()
        {
          var list = new GLib.List<unowned Key> ();
          try { role_service.foreach_local ((i, r, p) => list.append (i)); } catch (GLib.Error e)
            {
              assert_no_error (e);
            }
          return (owned) list;
        }

      public async ValuePeer pick (Key id)
        {
          Role? role = null;

          try { role = yield ((RoleProvider) role_service).lookup (id); assert (role != null && role is RoleSkeleton); } catch (GLib.Error e)
            {
              assert_no_error (e);
            }

          return ((RoleSkeleton) role).value_peer;
        }

      public async ValuePeer pick_any ()
        {
          try { return yield create_proxy ("testing"); } catch (GLib.Error e)
            {
              assert_no_error (e);
              assert_not_reached ();
            }
        }
    }
}
