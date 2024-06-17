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
  private const uint bytelen = KeyVal.BITLEN >> 3;

  [CCode (has_type_id = true, type_id = "(k_key_get_type ())")]
  [Compact (opaque = true)]

  public class Key
    {
      internal KeyVal value;
      public unowned uint8[] bytes { get
        {
          unowned var ar = (uint8[]) (void*) & value.bytes [0];
                    ar.length = (int) bytelen;
            return ar;
        }}

      public const uint BITLEN = 160;
      private const string charset = "0123456789abcdef";

      internal Key ()
        {
          static_assert (BITLEN == KeyVal.BITLEN);
        }

      public Key.from_bytes (GLib.Bytes bytes)
        {
          var builder = new KeyBuilder ();
          unowned var data = (uint8 []) bytes.get_data ();
          unowned var size = (size_t) bytelen;

          builder.update (data, data.length);
          builder.get_digest ((uint8[]) (void*) & value.bytes [0], ref size);
        }

      public Key.from_data (uint8[] data)
        {
          var builder = new KeyBuilder ();
          unowned var size = (size_t) bytelen;

          builder.update (data, data.length);
          builder.get_digest ((uint8[]) (void*) & value.bytes [0], ref size);
        }

      public Key.random (uint32 []? seed = null)
        {
          GLib.Rand rand;

          if (seed != null)

            rand = new GLib.Rand.with_seed_array (seed, seed.length);
          else
            {
              unowned var time = GLib.get_monotonic_time ();
              unowned var info = (uint32 []) & time;
              unowned var longs = sizeof (int32) / sizeof (uint32);
              
              rand = new GLib.Rand.with_seed_array (info, (uint) longs);
            }

          unowned var bytes = (uint8*) & value.bytes [0];

          for (unowned uint i = 0; i < bytelen; ++i)
            {
              bytes [i] = (uint8) rand.int_range (0, uint8.MAX);
            }
        }

      public Key.verbatim (uint8[] key) requires (key.length == value.bytes.length)
        {
          GLib.Memory.copy ((uint8[]) (void*) & value.bytes [0], (uint8[]) (void*) & key [0], bytelen);
        }

      public Key.zero ()
        {
          GLib.Memory.set ((uint8[]) (void*) & value.bytes [0], 0, bytelen);
        }

      public Key copy ()
        {
          return new Key.verbatim (value.bytes);
        }

      public static Key distance (Key a, Key b)
        {
          var result = new Key ();
          KeyVal.distance (out result.value, a.value, b.value);
          return result;
        }

      public static bool equal (Key a, Key b)
        {
          unowned var a_bytes = (uint8*) & a.value.bytes [0];
          unowned var b_bytes = (uint8*) & b.value.bytes [0];
          return 0 == GLib.Memory.cmp (a_bytes, b_bytes, bytelen);
        }

      public static GLib.Type get_type ()
        {
          return Key._get_type ();
        }

      [CCode (cheader_filename = "keytypes.h", cname = "_k_key_get_type")]
      public static extern GLib.Type _get_type ();

      public static uint hash (Key a)
        {
          unowned var bytes = (uint8*) & a.value.bytes [0];;
          unowned uint i, hash;

          for (i = 0, hash = 5381; i < bytelen; ++i)
            {
              hash = hash * 33 + bytes [i];
            }
          return hash;
        }

      public int nth_bit (uint nth) requires (nth >= 0 && nth < KeyVal.BITLEN) ensures (result == 0 || result == 1)
        {
          return value.nth_bit (nth);
        }

      public string to_string ()
        {
          var builder = new StringBuilder.sized (2 * bytelen);

          unowned var bytes = (uint8*) & value.bytes [0];
          unowned var first = true;

          for (unowned var i = 0; i < bytelen; ++i)
            {
              uint8 byte = bytes [i];
              char buffer[2] = { charset [byte >> 4], charset [byte & 0xf] };
              int off = first == false ? 0 : 2;

              builder.append_len (((string) buffer).offset (off), buffer.length - off);
              first = false;
            }
          return builder.free_and_steal ();
        }
    }

  [Compact (opaque = true)]

  public class KeyBuilder : GLib.Checksum
    {
      public KeyBuilder ()
        {
          base (KeyVal.CHECKSUM);
        }

      public Key end ()
        {
          var key = new Key ();
          var len = (size_t) bytelen;

          base.get_digest (key.value.bytes, ref len);
          return key;
        }
    }

  [CCode (ref_function = "k_key_list_ref", unref_function = "k_key_list_unref", type_id = "(k_key_list_get_type ())")]
  [Compact (opaque = true)]

  public class KeyList
    {
      private uint refs;
      private Key[] _keys;

      public struct Iterator
        {
          public unowned KeyList self;
          public unowned int index;
          public unowned int top;

          public Iterator (KeyList self)
            {
              this.index = -1;
              this.self = self;
              this.top = self._keys.length;
            }

          public unowned Key @get () { return self._keys [index]; }
          public unowned bool has_next () { return index < top; }
          public unowned bool next () { ++index; return has_next (); }
        }

      public KeyList (owned Key[] keys)
        {
          _keys = (owned) keys;
        }

      public static GLib.Type get_type ()
        {
          return Key._get_type ();
        }

      public Iterator iterator ()
        {
          return Iterator (this);
        }

      [CCode (cheader_filename = "keytypes.h", cname = "_k_key_list_get_type")]
      public static extern GLib.Type _get_type ();

      public unowned Key[] keys { get { return _keys; } }
      public unowned Key @get (uint index) { return _keys [index]; }
      public void @set (uint index, owned Key key) { _keys [index] = (owned) key; }

      extern void @free ();

      public unowned KeyList @ref ()
        {
          AtomicUint.inc (ref refs);
          return this;
        }

      public void @unref ()
        {
          if (AtomicUint.dec_and_test (ref refs))
            this.@free ();
        }
    }
}
