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
      GLib.Test.add_func (TESTPATHROOT + "/Integration/network/connect", () => (new TestNetworkConnect ()).run ());
      GLib.Test.add_func (TESTPATHROOT + "/Integration/network/insert", () => (new TestNetworkInsert ()).run ());
      GLib.Test.add_func (TESTPATHROOT + "/Integration/network/lookup", () => (new TestNetworkLookup ()).run ());
      GLib.Test.add_func (TESTPATHROOT + "/Integration/network/lookup_node", () => (new TestNetworkLookupNode ()).run ());
      return GLib.Test.run ();
    }

  public class DummyValueStore : GLib.Object, ValueStore
    {
      HashTable<Key, GLib.Value?> store;

      public GLib.List<weak Key> keys { owned get { return store.get_keys (); } }

      construct
        {
          store = new HashTable<Key, GLib.Value?> (GLib.str_hash, GLib.str_equal);
        }

      public async override bool insert_value (Key id, GLib.Value? value, GLib.Cancellable? cancellable)
        {
          var val = GLib.Value (value.type ());

          value.copy (ref val);
          store.insert (id.copy (), (owned) val);
          return true;
        }

      public async override GLib.Value? lookup_value (Key id, GLib.Cancellable? cancellable)
        {
          GLib.Value? value;

          if (store.lookup_extended (id, null, out value) == false)

            return null;
          else
            {
              var f = GLib.Value (value.type ());
                value.copy (ref f);
              return (owned) f;
            }
        }
    }

  [Compact (opaque = true)]

  public class NetTable : HashTable<Key, ValuePeer>
    {

      public NetTable ()
        {
          base (GLib.str_hash, GLib.str_equal);
        }

      public NetTable.random (int min_nodes = 100, int max_nodes = 1000)
        {
          this ();

          for (unowned var i = 0; i < GLib.Random.int_range (min_nodes, max_nodes); ++i)
            {
              var id = new Key.random ();
              var peer = new TestValuePeer (new DummyValueStore (), id, this);

              insert ((owned) id, peer);
            }
        }
    }

  public class TestValuePeer : ValuePeer
    {
      unowned NetTable net;

      public TestValuePeer (ValueStore value_store, Key id, NetTable net)
        {
          base (value_store, id);
          this.net = net;
        }

      unowned ValuePeer getother (Key peer) throws GLib.Error
        {
          unowned ValuePeer other;

          if ((other = net.lookup (peer)) == null)

            throw new PeerError.UNREACHABLE ("no node in net with id (%s)", peer.to_string ());

          return other;
        }

      protected async override Key[] find_peer (Key peer, Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          unowned var other = getother (peer);
          var peers = yield other.find_peer_complete (this.id, id, cancellable);

          foreach (unowned var peer_ in peers)
            {
              if (Key.equal (peer_, this.id) == false) buckets.insert (peer_);
            }
          return (owned) peers;
        }

      protected async override Kademlia.Value find_value (Key peer, Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          unowned var other = getother (peer);
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
          unowned var other = getother (peer);
          return yield other.store_value_complete (this.id, id, value, cancellable);
        }

      protected async override bool ping_peer (Key peer, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          unowned var other = getother (peer);
          return yield other.ping_peer_complete (this.id, cancellable);
        }
    }

  class TestNetworkConnect : AsyncTest
    {
      protected NetTable net = new NetTable.random ();

      protected override async void test ()
        {
          var keys = (GLib.List<unowned Key>) net.get_keys ();
          var peers = new (unowned Key) [keys.length ()];
          var indices = new uint [peers.length - 1];

          unowned uint i;
          unowned var list = keys;

          for (i = 0; list != null; ++i, list = list.next)
            {
              peers [i] = list.data;
            }

          for (i = 0; i < indices.length; ++i)
            {
              indices [i] = i + 1;
            }

          for (i = 0; i < GLib.Random.int_range (100, 1000); ++i)
            {
              var a = (int) GLib.Random.int_range (0, indices.length);
              var b = (int) GLib.Random.int_range (0, indices.length);
              var t = indices [a];

              indices [a] = indices [b];
              indices [b] = t;
            }

          var average = (double) 0;
          var timer = new GLib.Timer ();

          foreach (unowned var k in indices)
            {
              unowned var peer = net.lookup (peers [k]);

              timer.start ();

              try { yield peer.join (peers [0]); average += timer.elapsed (); } catch (GLib.Error e)
                {
                  assert_no_error (e);
                }
            }

          GLib.Test.message ("average join time: %04fs", average / (double) indices.length);
          GLib.Test.message ("network size: %i nodes", indices.length);
        }
    }

  class TestNetworkInsert : TestNetworkConnect
    {

      protected override async void test ()
        {
          yield base.test ();
          var keys = net.get_keys ();
          var peer = net.lookup (keys.nth_data (GLib.Random.int_range (0, (int32) keys.length ())));
          var ns = GLib.Random.int_range (100, 1000);

          var average = (double) 0;
          var timer = new GLib.Timer ();

          for (unowned var i = 0; i < ns; ++i)
            {
              var n = GLib.Random.next_int ();
              var v = GLib.Value (typeof (uint));

              v.set_uint (n);

              timer.start ();

              try { yield peer.insert (new Key.random (), v); average += timer.elapsed (); } catch (GLib.Error e)
                {
                  assert_no_error (e);
                }
            }

          GLib.Test.message ("average insert time: %04fs", average / (double) ns);
          GLib.Test.message ("insertions count: %i", ns);
        }
    }

  class TestNetworkLookup : TestNetworkConnect
    {

      protected override async void test ()
        {
          yield base.test ();
          var keys = net.get_keys ();
          var peer = net.lookup (keys.nth_data (GLib.Random.int_range (0, (int32) keys.length ())));
          var ns = GLib.Random.int_range (100, 1000);

          var unders = new GenericArray<Key> (ns);
          var values = new GenericArray<uint> (ns);

          for (unowned var i = 0; i < ns; ++i)
            {
              unders.add (new Key.random ());
              values.add (GLib.Random.next_int ());
            }

          var average = (double) 0;
          var timer = new GLib.Timer ();

          for (unowned var i = 0; i < ns; ++i)
            {
              timer.start ();

              try { yield peer.insert (unders.data [i], values.data [i]); average += timer.elapsed (); } catch (GLib.Error e)
                {
                  assert_no_error (e);
                }
            }

          GLib.Test.message ("average insert time: %04fs", average / (double) ns);
          GLib.Test.message ("insertions count: %i", ns);
          average = 0;

          for (unowned var i = 0; i < ns; ++i)
            {
              GLib.Value? value;

              timer.start ();

              try { value = yield peer.lookup (unders.data [i]); average += timer.elapsed (); } catch (GLib.Error e)
                {
                  assert_no_error (e);
                  break;
                }

              assert_true (value != null && value.holds (typeof (uint)));
              assert_cmpuint (values.data [i], GLib.CompareOperator.EQ, value.get_uint ());
            }

          GLib.Test.message ("average lookup time: %04fs", average / (double) ns);
          GLib.Test.message ("lookups count: %i", ns);
        }
    }

  class TestNetworkLookupNode : TestNetworkConnect
    {

      protected override async void test ()
        {
          yield base.test ();
          var keys = net.get_keys ();
          var peer = net.lookup (keys.nth_data (GLib.Random.int_range (0, (int32) keys.length ())));
          var ns = GLib.Random.int_range (100, 1000);

          var average = (double) 0;
          var timer = new GLib.Timer ();

          for (unowned var i = 0; i < ns; ++i)
            {
              var closest_expected = new GenericArray<Key> ();
              Key[] closest_got;
              Key key = new Key.random ();

              CompareDataFunc<Key> sorter = (a, b) =>
                {
                  return Key.distance (a, key) - Key.distance (b, key);
                };

              foreach (unowned var other in net.get_values ())
                {
                  closest_expected.add (other.id.copy ());
                  closest_expected.sort_values_with_data (sorter);
                  closest_expected.length = int.min (closest_expected.length, (int) Buckets.MAXSPAN);
                }

              closest_expected.sort_values_with_data (sorter);

              timer.start ();

              try { closest_got = yield peer.lookup_node (key); average += timer.elapsed (); } catch (GLib.Error e)
                {
                  assert_no_error (e);
                  return;
                }

              uint join = 0;

              foreach (unowned var a in closest_got)
              foreach (unowned var b in closest_expected)
                {
                  join = Key.equal (a, b) == false ? join : 1 + join;
                }

              assert_cmpuint (0, GLib.CompareOperator.LT, join);
              assert_cmpuint (Key.distance (closest_got [0], key), GLib.CompareOperator.EQ, Key.distance (closest_got [0], key));
            }

          GLib.Test.message ("lookup_node average time: %04fs", average / (double) ns);
          GLib.Test.message ("lookup_node count: %i", ns);
        }
    }
}
