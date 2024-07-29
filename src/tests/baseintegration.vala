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
  public class DummyValueStore : GLib.Object, ValueStore
    {
      HashTable<Key, GLib.Value?> store;

      construct
        {
          store = new HashTable<Key, GLib.Value?> (Key.hash, Key.equal);
        }

      public async override bool insert_value (Key id, GLib.Value? value, GLib.Cancellable? cancellable)
        {
          var val = GLib.Value (value.type ());

          value.copy (ref val);
          lock (store) store.insert (id.copy (), (owned) val);
          return true;
        }

      public async override GLib.Value? lookup_value (Key id, GLib.Cancellable? cancellable)
        {
          unowned GLib.Value? value;

          lock (store) if (store.lookup_extended (id, null, out value) == false)

            return null;
          else
            {
              var f = GLib.Value (value.type ());
                value.copy (ref f);
              return (owned) f;
            }
        }
    }

  public interface PeerProvider : GLib.Object
    {
      public abstract GLib.List<unowned ValuePeer> list_peers ();
      public abstract GLib.List<unowned Key> list_peers_id ();
      public abstract async ValuePeer pick (Key key);
      public abstract async ValuePeer pick_any ();
    }

  public abstract class TestIntegrationBase : AsyncTest
    {
      public PeerProvider net { get; construct; }

      protected TestIntegrationBase (PeerProvider net)
        {
          Object (net : net);
        }
    }

  public class TestIntegrationConnect : TestIntegrationBase
    {

      public TestIntegrationConnect (PeerProvider net)
        {
          base (net);
        }

      protected override async void test ()
        {
          var keys = (GLib.List<unowned Key>) net.list_peers_id ();
          assert (keys.length () > 0);

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
              var peer = yield net.pick (peers [k]);

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

  public class TestIntegrationInsert : TestIntegrationConnect
    {

      public TestIntegrationInsert (PeerProvider hub)
        {
          base (hub);
        }

      protected override async void test ()
        {
          yield base.test ();
          var peer = yield net.pick_any ();
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

  public class TestIntegrationInsertExotic : TestIntegrationConnect
    {

      public TestIntegrationInsertExotic (PeerProvider hub)
        {
          base (hub);
        }

      protected override async void test ()
        {
          yield base.test ();
          var peer = yield net.pick_any ();

          var values = new GLib.Value []
            {
              (int8) 8,
              (uint8) 8,
              (int16) 8,
              (uint16) 8,
              (int32) 8,
              (uint32) 8,
              (int64) 8,
              (uint64) 8,
              (char) 'a',
              (string) "testing",
              new GLib.Bytes ("testing".data),
            };

          var ids = new Key [values.length];

          for (unowned int i = 0; i < ids.length; ++i)

            ids [i] = new Key.random ();

          for (unowned int i = 0; i < ids.length; ++i) try { yield peer.insert (ids [i], values [i]); } catch (GLib.Error e)
            {
              assert_no_error (e);
            }

          for (unowned int i = 0; i < ids.length; ++i) try { assert_cmpvariant (GValr.nat2net (values [i]), GValr.nat2net (yield peer.lookup (ids [i]))); } catch (GLib.Error e)
            {
              assert_no_error (e);
            }
        }
    }

  public class TestIntegrationLookup : TestIntegrationConnect
    {

      public TestIntegrationLookup (PeerProvider hub)
        {
          base (hub);
        }

      protected override async void test ()
        {
          yield base.test ();
          var ns = GLib.Random.int_range (100, 1000);
          var peer = yield net.pick_any ();

          var values = new HashTable<Key, uint> (Key.hash, Key.equal);
          var iter = (HashTableIter<Key, uint>?) null;

          unowned Key id_;
          unowned uint value_;

          for (unowned var i = 0; i < ns; ++i)
            {
              values.insert (new Key.random (), GLib.Random.next_int ());
            }

          ns = (int32) values.length;

          var average = (double) 0;
          var timer = new GLib.Timer ();

          while (true)
            {
              GLib.Value? value;
              timer.start ();

              try { value = yield peer.lookup (new Key.random ()); average += timer.elapsed (); } catch (GLib.Error e)
                {
                  assert_no_error (e);
                  break;
                }

              assert_true (value == null);
              break;
            }

          GLib.Test.message ("unset lookup time: %04fs", average);

          iter = HashTableIter<Key, uint> (values);
          average = 0;

          while (iter.next (out id_, out value_))
            {
              timer.start ();

              try { yield peer.insert (id_, value_); average += timer.elapsed (); } catch (GLib.Error e)
                {
                  assert_no_error (e);
                }
            }

          GLib.Test.message ("average insert time: %04fs", average / (double) ns);
          GLib.Test.message ("insertions count: %i", ns);

          iter = HashTableIter<Key, uint> (values);
          average = 0;

          while (iter.next (out id_, out value_))
            {
              GLib.Value? value;

              timer.start ();

              try { value = yield peer.lookup (id_); average += timer.elapsed (); } catch (GLib.Error e)
                {
                  assert_no_error (e);
                  break;
                }

              assert_true (value != null && value.holds (typeof (uint)));
              assert_cmpuint (value_, GLib.CompareOperator.EQ, value.get_uint ());
            }

          GLib.Test.message ("average lookup time: %04fs", average / (double) ns);
          GLib.Test.message ("lookups count: %i", ns);
        }
    }

  public class TestIntegrationLookupNode : TestIntegrationConnect
    {

      public TestIntegrationLookupNode (PeerProvider hub)
        {
          base (hub);
        }

      protected override async void test ()
        {
          yield base.test ();
          var peer = yield net.pick_any ();
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

              foreach (unowned var other in net.list_peers ())
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
