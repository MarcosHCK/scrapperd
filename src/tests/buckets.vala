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
      GLib.Test.add_func (TESTPATHROOT + "/Buckets/drop", () => test_drop (new Key.random (), new Key.random ()));
      GLib.Test.add_func (TESTPATHROOT + "/Buckets/insert", () => test_insert (new Key.random (), new Key.random ()));
      GLib.Test.add_func (TESTPATHROOT + "/Buckets/nearest", () => test_nearest (new Key.random (), new Key.random (), new Key.random ()));
      GLib.Test.add_func (TESTPATHROOT + "/Buckets/nearest2", () => test_nearest2 (new Key.random (), 10000));
      GLib.Test.add_func (TESTPATHROOT + "/Buckets/new", () => test_new (new Key.random ()));
      return GLib.Test.run ();
    }

  static void test_drop (Key self, Key key)
    {
      var buckets = new Buckets (self.copy ());

      GLib.Test.message ("self: %s", self.to_string ());
      GLib.Test.message ("key: %s", key.to_string ());

      CompareFunc<Key> find_key = (a, b) => Key.equal (a, b) ? 0 : 1;

      buckets.insert (key);
      assert_true (buckets.nearest (key).length () == 2);
      assert_true (buckets.nearest (key).find_custom (key, find_key) != null);

      buckets.drop (key);
      assert_true (buckets.nearest (key).length () == 1);
      assert_true (buckets.nearest (key).find_custom (key, find_key) == null);
    }

  static void test_insert (Key self, Key key)
    {
      var buckets = new Buckets (self.copy ());

      GLib.Test.message ("self: %s", self.to_string ());
      GLib.Test.message ("key: %s", key.to_string ());

      buckets.insert (key);
      assert_true (buckets.nearest (key).length () == 2);
    }

  static void test_nearest (Key self, Key key1, Key key2)
    {
      var buckets = new Buckets (self.copy ());
      var list1 = buckets.nearest (self);
      var list2 = buckets.nearest (key1);
      var list3 = buckets.nearest (key2);

      buckets.insert (key1);
      var list4 = buckets.nearest (self);
      var list5 = buckets.nearest (key1);
      var list6 = buckets.nearest (key2);

      buckets.insert (key2);
      var list7 = buckets.nearest (self);
      var list8 = buckets.nearest (key1);
      var list9 = buckets.nearest (key2);

      GLib.Test.message ("self: %s", self.to_string ());
      GLib.Test.message ("key1: %s", key1.to_string ());
      GLib.Test.message ("key2: %s", key2.to_string ());

      int i = 1;

      foreach (unowned var list in new (unowned GLib.SList<Kademlia.Key>) [] { list1, list2, list3, list4, list5, list6, list7, list8, list9 })
        {
          GLib.Test.message ("list%i:", i++);

          foreach (unowned var data in list)

            GLib.Test.message ("  key: %s", data.to_string ());
        }

      CompareFunc<Key> find_key = (a, b) => Key.equal (a, b) ? 0 : 1;

      assert_true (list1.length () == 1);
      assert_true (list1.find_custom (self, find_key) != null);
      assert_true (list2.length () == 1);
      assert_true (list2.find_custom (self, find_key) != null);
      assert_true (list3.length () == 1);
      assert_true (list3.find_custom (self, find_key) != null);

      assert_true (list4.length () == 2);
      assert_true (list4.find_custom (self, find_key) != null);
      assert_true (list5.length () == 2);
      assert_true (list5.find_custom (key1, find_key) != null);
      assert_true (list6.length () == 2);

      assert_true (list7.length () == 3);
      assert_true (list7.find_custom (self, find_key) != null);
      assert_true (list8.length () == 3);
      assert_true (list8.find_custom (key1, find_key) != null);
      assert_true (list9.length () == 3);
      assert_true (list9.find_custom (key2, find_key) != null);
    }

  static void test_nearest2 (owned Key self, uint keycount, uint record = 10)
    {
      var buckets = new Buckets (self.copy ());
      var samples = new List<Key> ();

      GLib.Test.message ("self: %s", self.to_string ());

      for (unowned var i = 0, j = 0; i < keycount; ++i)
        {
          var key = new Key.random ();
          var added = buckets.insert (key);

          if (added && j < record)
            ++j;
          else if (added)
            {
              samples.append ((owned) key);
              j = 0;
            }
        }

      CompareFunc<Key> find_key = (a, b) => Key.equal (a, b) ? 0 : 1;

      foreach (unowned var sample in samples)
        {
          var ks = buckets.nearest (sample);

          GLib.Test.message ("nearest to %s:", sample.to_string ());

          foreach (unowned var k in ks)
            {
              GLib.Test.message ("  key: %s", k.to_string ());
            }

          assert_true (ks.length () == Buckets.MAXSPAN);
          assert_true (ks.find_custom (sample, find_key) != null);
        }
    }

  static void test_new (owned Key self)
    {
      var buckets = new Buckets ((owned) self);

      GLib.Test.message ("self: %s", buckets.self.to_string ());
    }
}
