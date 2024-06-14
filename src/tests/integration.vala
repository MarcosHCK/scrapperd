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

[CCode (cprefix = "K", lower_case_cprefix = "k_")]

namespace Kademlia
{
  public static int main (string[] args)
    {
      GLib.Test.init (ref args, null);
      GLib.Test.add_func (TESTPATHROOT + "/Integration/network/connect", () => (new TestNetworkConnect ()).run ());
      GLib.Test.add_func (TESTPATHROOT + "/Integration/network/insert", () => (new TestNetworkInsert ()).run ());
      GLib.Test.add_func (TESTPATHROOT + "/Integration/network/lookup", () => (new TestNetworkLookup ()).run ());
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

      public NetTable.random ()
        {
          this ();

          for (unowned var i = 0; i < GLib.Random.int_range (10, 100); ++i)
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
          else
            {
              other.buckets.insert (this.id);
              return other;
            }
        }

      protected async override Key[] find_peer (Key peer, Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          unowned var other = getother (peer);

          var near = other.nearest (id);
          var ar = new Key [near.length ()];

          unowned var link = near;
          unowned int i;

          for (i = 0; link != null; ++i, link = link.next)

            ar [i] = link.data.copy ();

          return (owned) ar;
        }

      protected async override bool ping_peer (Key peer, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          return getother (peer) != null;
        }

      protected async override Value find_value (Key peer, Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          unowned var other = getother (peer);
          GLib.Value? value;

          if ((value = yield other.lookup (id, cancellable)) != null)

            return new Value.inmediate ((owned) value);
          else
            return new Value.delegated (yield find_peer (peer, id, cancellable));
        }

      protected async override bool store_value (Key peer, Key id, GLib.Value? value = null, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          return yield getother (peer).insert (id, value, cancellable);
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

          foreach (unowned var k in indices)
            {
              unowned var peer = net.lookup (peers [k]);

              try { yield peer.connectto (peers [0]); } catch (GLib.Error e)
                {
                  assert_no_error (e);
                }
            }
        }
    }

  class TestNetworkInsert : TestNetworkConnect
    {

      protected override async void test ()
        {
          yield base.test ();
          var keys = net.get_keys ();
          var peer = net.lookup (keys.nth_data (GLib.Random.int_range (0, (int32) keys.length ())));

          for (unowned var i = 0; i < GLib.Random.int_range (10, 100); ++i)
            {
              var n = GLib.Random.next_int ();
              var v = GLib.Value (typeof (uint));

              v.set_uint (n);

              try { yield peer.insert (new Key.random (), v); } catch (GLib.Error e)
                {
                  assert_no_error (e);
                }
            }
        }
    }

  class TestNetworkLookup : TestNetworkConnect
    {

      protected override async void test ()
        {
          yield base.test ();
          var keys = net.get_keys ();
          var peer = net.lookup (keys.nth_data (GLib.Random.int_range (0, (int32) keys.length ())));

          var unders = new GenericArray<Key> ();
          var values = new GenericArray<uint> ();

          for (unowned var i = 0; i < GLib.Random.int_range (10, 100); ++i)
            {
              unders.add (new Key.random ());
              values.add (GLib.Random.next_int ());
            }

          for (unowned var i = 0; i < unders.length; ++i)
            {
              try { yield peer.insert (unders.data [i], values.data [i]); } catch (GLib.Error e)
                {
                  assert_no_error (e);
                }
            }

          for (unowned var i = 0; i < unders.length; ++i)
            {
              GLib.Value? value;

              try { value = yield peer.lookup (unders.data [i]); } catch (GLib.Error e)
                {
                  assert_no_error (e);
                  break;
                }

              assert_cmpuint (values.data [i], GLib.CompareOperator.EQ, value.get_uint ());
            }
        }
    }
}
