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
            return (owned) value;
        }
    }

  public class TestValuePeer : ValuePeer
    {

      public TestValuePeer (ValueStore value_store, Key? id = null)
        {
          base (value_store, id);
        }
    }

  public static int main (string[] args)
    {
      GLib.Test.init (ref args, null);
      GLib.Test.add_func (TESTPATHROOT + "/ValuePeer/insert", () => (new TestInsert ()).run ());
      GLib.Test.add_func (TESTPATHROOT + "/ValuePeer/no_handle", () => (new TestNoHandle ()).run ());
      GLib.Test.add_func (TESTPATHROOT + "/ValuePeer/lookup", () => (new TestLookup ()).run ());
      GLib.Test.add_func (TESTPATHROOT + "/ValuePeer/new", () => test_new ());
      return GLib.Test.run ();
    }

  class TestInsert : AsyncTest
    {

      protected async override void test ()
        {
          var value_store = new DummyValueStore ();
          var value_peer = new TestValuePeer (value_store);

          for (unowned var i = 0; i < GLib.Random.int_range (0, 100); ++i)
            {
              var id2 = new Key.random ();
              var value = GLib.Value (typeof (uint));

              value.set_uint (GLib.Random.next_int ());

              try { yield value_peer.insert (id2, value); } catch (GLib.Error e)
                {
                  assert_no_error (e);
                }
            }
        }
    }

  class TestLookup : AsyncTest
    {

      protected async override void test ()
        {
          var value_store = new DummyValueStore ();
          var value_peer = new TestValuePeer (value_store);

          for (unowned var i = 0; i < GLib.Random.int_range (0, 100); ++i)
            {
              var id2 = new Key.random ();
              var value = GLib.Value (typeof (uint));

              value.set_uint (GLib.Random.next_int ());

              try { yield value_store.insert_value (id2, value); } catch (GLib.Error e)
                {
                  assert_no_error (e);
                }
            }

          foreach (unowned var key in value_store.keys) try
            {
              assert_false (null == yield value_peer.lookup (key));
            }
          catch (GLib.Error e)
            {
              assert_no_error (e);
            }
        }
    }

  class TestNoHandle : AsyncTest
    {

      protected async override void test ()
        {
          var value_store = new DummyValueStore ();
          var value_peer = new TestValuePeer (value_store);
          var id = new Key.random ();

          try { yield value_peer.lookup (id); } catch (GLib.Error e)
            {
              assert_no_error (e);
            }
        }
    }

  static void test_new ()
    {
      GLib.Test.message ("key: %s", (new TestValuePeer (new DummyValueStore ())).id.to_string ());
    }
}
