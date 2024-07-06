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
              var value_peer = new PeerImpl (this, value_store, id);
              var node = new NodeSkeleton (this);
              var role = new RoleSkeleton (this, "testing", value_peer);

              add_contact (id, new Address [0]);
              add_contact_complete (id, node, role);
            }
        }

      public GLib.List<ValuePeer> list_peers ()
        {
          var list = new GLib.List<ValuePeer> ();

          foreach (unowned var role in roles.get_values ())

            list.append (((RoleSkeleton) role).value_peer);

          return (owned) list;
        }

      public GLib.List<unowned Key> list_peers_id ()
        {
          return roles.get_keys ();
        }

      public ValuePeer pick (Key id)
        {
          var role = roles.lookup (id); assert (role != null);
          return ((RoleSkeleton) role).value_peer;
        }

      public ValuePeer pick_any () requires (roles.length > 0)
        {
          var iter = HashTableIter<Key, Role> (roles);
          var role = (Role?) null;
          iter.next (null, out role);
          return ((RoleSkeleton) role).value_peer;
        }
    }
}
