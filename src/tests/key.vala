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
      GLib.Test.add_func (TESTPATHROOT + "/Key/copy", () => test_copy ());
      GLib.Test.add_func (TESTPATHROOT + "/Key/distance", () => test_distance ());
      GLib.Test.add_func (TESTPATHROOT + "/Key/equal", () => test_equal ());
      GLib.Test.add_func (TESTPATHROOT + "/Key/hash", () => test_hash ());
      GLib.Test.add_func (TESTPATHROOT + "/Key/new_from_bytes", () => test_new_from_bytes ("test data".data));
      GLib.Test.add_func (TESTPATHROOT + "/Key/new_from_data", () => test_new_from_data ("test data".data));
      GLib.Test.add_func (TESTPATHROOT + "/Key/new_random/with_seed", () => test_new_random (new uint32 [] { 13, 33 }));
      GLib.Test.add_func (TESTPATHROOT + "/Key/new_random/without_seed", () => test_new_random ());
      return GLib.Test.run ();
    }

  static void test_copy ()
    {
      var key1 = new Key.random ();
      var key2 = key1.copy ();

      GLib.Test.message ("key1: %s", key1.to_string ());
      GLib.Test.message ("key2: %s", key2.to_string ());

      assert_true (Key.equal (key1, key2));
    }

  static void test_distance ()
    {
      var key1 = new Key.random ();
      var key2 = new Key.random ();
      var zero = new Key.zero ();

      GLib.Test.message ("key1: %s", key1.to_string ());
      GLib.Test.message ("key2: %s", key2.to_string ());
      GLib.Test.message ("distance: %s", Key.distance (key1, key2).to_string ());

      assert_true (Key.equal (Key.distance (key1, key2), Key.distance (key2, key1)));
      assert_true (Key.equal (Key.distance (key1, key1), zero));
      assert_true (Key.equal (Key.distance (key1, zero), key1));
    }

  static void test_equal ()
    {
      var key1 = new Key.zero ();
      var key2 = new Key.random ();

      GLib.Test.message ("key1: %s", key1.to_string ());
      GLib.Test.message ("key2: %s", key2.to_string ());

      assert_true (Key.equal (key1, key1));
      assert_true (Key.equal (key2, key2));
      assert_false (Key.equal (key1, key2));
    }

  static void test_hash ()
    {
      var key1 = new Key.random ();
      var key2 = new Key.random ();

      GLib.Test.message ("key1: %s", key1.to_string ());
      GLib.Test.message ("key2: %s", key2.to_string ());

      assert_true (Key.hash (key1) == Key.hash (key1));
      assert_true (Key.hash (key2) == Key.hash (key2));
      assert_true (Key.hash (key1) != Key.hash (key2));
    }

  static void test_new_from_bytes (uint8[] data)
    {
      var bytes = new GLib.Bytes (data);
      var key1 = new Key.from_bytes (bytes);
      var key2 = new Key.from_bytes (bytes);
      var zero = new Key.zero ();

      GLib.Test.message ("key1: %s", key1.to_string ());
      GLib.Test.message ("key2: %s", key2.to_string ());
      assert_false (Key.equal (key1, zero));
      assert_true (Key.equal (key1, key2));
    }

  static void test_new_from_data (uint8[] data)
    {
      var key1 = new Key.from_data (data);
      var key2 = new Key.from_data (data);
      var zero = new Key.zero ();

      GLib.Test.message ("key1: %s", key1.to_string ());
      GLib.Test.message ("key2: %s", key2.to_string ());
      assert_false (Key.equal (key1, zero));
      assert_true (Key.equal (key1, key2));
    }

  static void test_new_random (uint32[]? seed = null)
    {
      var key1 = new Key.random (seed);
      var key2 = new Key.random (seed);
      var zero = new Key.zero ();

      GLib.Test.message ("key1: %s", key1.to_string ());
      GLib.Test.message ("key2: %s", key2.to_string ());

      if (seed != null)

        assert_true (Key.equal (key1, key2));
      else
        assert_false (Key.equal (key1, key2));

      assert_false (Key.equal (key1, zero));
      assert_false (Key.equal (key2, zero));
    }
}