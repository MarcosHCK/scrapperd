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

      public override async Kademlia.Key[] enumerate_staled_values (GLib.Cancellable? cancellable)
        {
          return new Key [0];
        }

      public async bool insert_value (Key id, GLib.Value? value, GLib.Cancellable? cancellable)
        {
          var val = GLib.Value (value.type ());

          value.copy (ref val);
          lock (store) store.insert (id.copy (), (owned) val);
          return true;
        }

      public async GLib.Value? lookup_value (Key id, GLib.Cancellable? cancellable)
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

          for (i = 0; i < GLib.Test.rand_int_range (100, 1000); ++i)
            {
              var a = (int) GLib.Test.rand_int_range (0, indices.length);
              var b = (int) GLib.Test.rand_int_range (0, indices.length);
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
          var ns = GLib.Test.rand_int_range (100, 1000);

          var average = (double) 0;
          var timer = new GLib.Timer ();

          for (unowned var i = 0; i < ns; ++i)
            {
              var n = GLib.Test.rand_int ();
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

      static GLib.Bytes rand_bytes (size_t sz)
        {
          var ar = new uint8 [sz];
          var begin = (int32) uint8.MIN;
          var end = (int32) uint8.MAX;

          for (size_t i = 0; i < sz; ++i) ar [i] = (uint8) GLib.Test.rand_int_range (begin, end);
          return new GLib.Bytes.take ((owned) ar);
        }

      static int rand_enum<T> (GLib.Type gtype = typeof (T)) requires (gtype.is_enum ())
        {
          int32 begin = 0, end = 0;
          var klass = (EnumClass) gtype.class_ref ();

          foreach (unowned var value in klass.values) if (value.value > end) end = value.value;
          return GLib.Test.rand_int_range (begin, end + 1);
        }

      static uint rand_flags<T> (GLib.Type gtype = typeof (T)) requires (gtype.is_flags ())
        {
          var acc = (uint) 0;
          var mask = (uint) 0;
          var klass = (FlagsClass) gtype.class_ref ();
          var used = (int) 0;

          foreach (unowned var value in klass.values)
            {
              if (used % (sizeof (uint) << 3) == 0) mask = (uint) GLib.Test.rand_int ();
              if (1 == (mask & 1)) acc |= value.value;
              mask >>= 1; ++used;
            }
          return acc;
        }

      static GLib.Bytes rand_vector (size_t minsz = 1, size_t maxsz = int.MAX)
        {
          var sz = (size_t) GLib.Test.rand_int_range ((int32) minsz, (int32) maxsz);
          var bytes = (Bytes) rand_bytes (sz);
          return (owned) bytes;
        }

      public TestIntegrationInsertExotic (PeerProvider hub)
        {
          base (hub);
        }

      protected override async void test ()
        {
          yield base.test ();
          var peer = yield net.pick_any ();

          var _bool = GLib.Value (typeof (bool)); _bool.set_boolean (GLib.Test.rand_bit ());
          var _bytes = GLib.Value (typeof (GLib.Bytes)); _bytes.set_boxed (rand_vector (10, 100));
          var _double = GLib.Value (typeof (double)); _double.set_double ((double) GLib.Test.rand_double ());
          var _enum = GLib.Value (typeof (GLib.FileMonitorEvent)); _enum.set_enum (rand_enum<GLib.FileMonitorEvent> ());
          var _flags = GLib.Value (typeof (GLib.SubprocessFlags)); _flags.set_flags (rand_flags<GLib.SubprocessFlags> ());
          var _float = GLib.Value (typeof (float)); _float.set_float ((float) GLib.Test.rand_double ());
          var _int = GLib.Value (typeof (int)); _int.set_int ((int) GLib.Test.rand_int_range (int.MIN, int.MAX));
          var _int64 = GLib.Value (typeof (int64)); _int64.set_int64 ((int) GLib.Test.rand_int_range (int.MIN, int.MAX));
          var _int8 = GLib.Value (typeof (int8)); _int8.set_schar ((int8) GLib.Test.rand_int_range (int8.MIN, int8.MAX));
          var _long = GLib.Value (typeof (long)); _long.set_long ((long) GLib.Test.rand_int_range (int32.MIN, int32.MAX));
          var _string = GLib.Value (typeof (string)); _string.set_string (Base64.encode (rand_vector (10, 20).get_data ()));
          var _uint = GLib.Value (typeof (uint)); _uint.set_uint ((uint) GLib.Test.rand_int_range (int.MIN, int.MAX));
          var _uint64 = GLib.Value (typeof (uint64)); _uint64.set_uint64 ((uint) GLib.Test.rand_int_range (int.MIN, int.MAX));
          var _uint8 = GLib.Value (typeof (uint8)); _uint8.set_uchar ((uint8) GLib.Test.rand_int_range (uint8.MIN, uint8.MAX));
          var _ulong = GLib.Value (typeof (ulong)); _ulong.set_ulong ((ulong) GLib.Test.rand_int_range (int32.MIN, int32.MAX));

          var values = new GLib.Value [] { _bool, _bytes, _double, _enum, _flags, _float, _int, _int64, _int8, _long, _string, _uint, _uint64, _uint8, _ulong };
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
          var ns = GLib.Test.rand_int_range (100, 1000);
          var peer = yield net.pick_any ();

          var values = new HashTable<Key, uint> (Key.hash, Key.equal);
          var iter = (HashTableIter<Key, uint>?) null;

          unowned Key id_;
          unowned uint value_;

          for (unowned var i = 0; i < ns; ++i)
            {
              values.insert (new Key.random (), GLib.Test.rand_int ());
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
          var ns = GLib.Test.rand_int_range (100, 1000);

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
