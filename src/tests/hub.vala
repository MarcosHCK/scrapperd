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
      GLib.Test.add_func (TESTPATHROOT + "/Hub/lookup", () => (new TestIntegrationLookup (new TestHub ())).run ());
      GLib.Test.add_func (TESTPATHROOT + "/Hub/lookup_node", () => (new TestIntegrationLookupNode (new TestHub ())).run ());
      GLib.Test.add_func (TESTPATHROOT + "/Hub/new", () => new TestHub ());
      return GLib.Test.run ();
    }

  public class TestHub : Hub, PeerProvider
    {

      public TestHub (int min_nodes = 100, int max_nodes = 1000)
        {
          for (unowned var i = 0; i < GLib.Random.int_range (min_nodes, max_nodes); ++i)
            {
              var id = new Key.random ();
              var value_store = new DummyValueStore ();
              var value_peer = new PeerImpl (value_store, id);

              add_local_peer ("testing", value_peer);
            }
        }

      public GLib.List<unowned ValuePeer> list_peers ()
        {
          var list = new GLib.List<unowned ValuePeer> ();

          foreach (unowned var local in locals.get_values ())

            list.append (local.peer);

          return (owned) list;
        }

      public GLib.List<unowned Key> list_peers_id ()
        {
          return locals.get_keys ();
        }

      public async ValuePeer pick (Key id)
        {
          Role? role = null;

          try { role = yield lookup_role (id); assert (role != null && role is RoleSkeleton); } catch (GLib.Error e)
            {
              assert_no_error (e);
            }

          return ((RoleSkeleton) role).value_peer;
        }

      public async ValuePeer pick_any () requires (roles.length > 0)
        {
          try { return yield create_proxy ("testing"); } catch (GLib.Error e)
            {
              assert_no_error (e);
              assert_not_reached ();
            }
        }

      public override async bool reconnect (Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          throw new PeerError.UNREACHABLE ("can not reach node '%s'", id.to_string ());
        }
    }
}
