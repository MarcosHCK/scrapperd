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

namespace Testing
{
  public static int main (string[] args)
    {
      GLib.Test.init (ref args, null);
      GLib.Test.add_func (TESTPATHROOT + "/Integration/connect", () => (new TestIntegrationConnect (new TestHub ())).run ());
      GLib.Test.add_func (TESTPATHROOT + "/Integration/insert", () => (new TestIntegrationInsert (new TestHub ())).run ());
      GLib.Test.add_func (TESTPATHROOT + "/Integration/lookup", () => (new TestIntegrationLookup (new TestHub ())).run ());
      GLib.Test.add_func (TESTPATHROOT + "/Integration/lookup_node", () => (new TestIntegrationLookupNode (new TestHub ())).run ());
      return GLib.Test.run ();
    }

  public class TestHub : GLib.Object, PeerProvider
    {
      private HashTable<Key, ValuePeer> table;

      construct
        {
          table = new HashTable<Key, ValuePeer> (GLib.str_hash, GLib.str_equal);
        }

      public TestHub (int min_nodes = 100, int max_nodes = 1000)
        {
          for (unowned var i = 0; i < GLib.Random.int_range (min_nodes, max_nodes); ++i)
            {
              var id = new Key.random ();
              var peer = new TestValuePeer (new DummyValueStore (), id, this);

              table.insert ((owned) id, peer);
            }
        }

      public GLib.List<ValuePeer> list_peers ()
        {
          var list = new GLib.List<ValuePeer> ();

          foreach (unowned var peer in table.get_values ())

            list.append (peer);

          return (owned) list;
        }

      public GLib.List<unowned Key> list_peers_id ()
        {
          return table.get_keys ();
        }

      public ValuePeer pick (Key id)
        {
          var peer = table.lookup (id); assert (peer != null);
          return (owned) peer;
        }

      public ValuePeer pick_any () requires (table.length > 0)
        {
          var iter = HashTableIter<Key, ValuePeer> (table);
          var peer = (ValuePeer?) null;
          iter.next (null, out peer);
          return (owned) peer;
        }
    }

  public class TestValuePeer : ValuePeer
    {
      unowned TestHub net;

      public TestValuePeer (ValueStore value_store, Key id, TestHub net)
        {
          base (value_store, id);
          this.net = net;
        }

      ValuePeer getother (Key peer) throws GLib.Error
        {
          ValuePeer other;

          if ((other = net.pick (peer)) == null)

            throw new PeerError.UNREACHABLE ("no node in net with id (%s)", peer.to_string ());

          return other;
        }

      protected async override Key[] find_peer (Key peer, Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var other = getother (peer);
          var peers = yield other.find_peer_complete (this.id, id, cancellable);

          foreach (unowned var peer_ in peers)
            {
              if (Key.equal (peer_, this.id) == false) buckets.insert (peer_);
            }
          return (owned) peers;
        }

      protected async override Kademlia.Value find_value (Key peer, Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var other = getother (peer);
          var value = yield other.find_value_complete (this.id, id, cancellable);

          if (value.is_delegated)
          foreach (unowned var peer_ in value.keys)
            {
              if (Key.equal (peer_, this.id) == false) buckets.insert (peer_);
            }

          return (owned) value;
        }

      protected async override bool store_value (Key peer, Key id, GLib.Value? value = null, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var other = getother (peer);
          return yield other.store_value_complete (this.id, id, value, cancellable);
        }

      protected async override bool ping_peer (Key peer, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var other = getother (peer);
          return yield other.ping_peer_complete (this.id, cancellable);
        }
    }
}
