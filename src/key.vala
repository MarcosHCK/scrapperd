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

  public errordomain KeyError
    {
      FAILED,
      INVALID_KEY;

      public static extern GLib.Quark quark ();
    }

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

      public const uint BITLEN = 256;
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

      public Key.parse (string key, int length = -1) throws GLib.Error
        {
          if ((length = (length >= 0 ? length : key.length)) != (bytelen << 1))
            {
              throw new KeyError.INVALID_KEY ("invalid serialized key length");
            }

          unowned var bytes = (uint8[]) (void*) & value.bytes [0];

          for (unowned var i = 0; i < bytelen; ++i)
            {
              uint8 b = 0;
              char c;

              if ((c = key [(i << 1) + 0].tolower ()).isalnum () == false || c > 'f')

                throw new KeyError.INVALID_KEY ("invalid serialized key length");
              else
                b |= c.isdigit () ? c - '0' : 10 + (c - 'a');

              b <<= 4;

              if ((c = key [(i << 1) + 1].tolower ()).isalnum () == false || c > 'f')

                throw new KeyError.INVALID_KEY ("invalid serialized key length");
              else
                b |= c.isdigit () ? c - '0' : 10 + (c - 'a');

              bytes [i] = b;
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

      public static int distance (Key a, Key b)

          ensures (result == -1 || result >= 0)
        {
          return KeyVal.log (a.value, b.value);
        }

      public static bool equal (Key a, Key b)
        {
          return (void*) a == (void*) b || KeyVal.cmp (a.value, b.value);
        }

      public static GLib.Type get_type ()
        {
          return Key._get_type ();
        }

      [CCode (cheader_filename = "keytypes.h", cname = "_k_key_get_type")]
      public static extern GLib.Type _get_type ();

      public static uint hash (Key a)
        {
          return a.value.hash ();
        }

      public int nth_bit (uint nth) requires (nth >= 0 && nth < KeyVal.BITLEN) ensures (result == 0 || result == 1)
        {
          return value.nth_bit (nth);
        }

      public string to_string ()
        {
          var builder = new StringBuilder.sized (2 * bytelen);

          unowned var bytes = (uint8*) & value.bytes [0];

          for (unowned var i = 0; i < bytelen; ++i)
            {
              uint8 b = bytes [i];
              builder.append_c (charset [b >> 4]);
              builder.append_c (charset [b & 0xf]);
            }

          return builder.free_and_steal ();
        }

      public static Key xor (Key a, Key b)
        {
          var x = new Key ();
          KeyVal.xor (out x.value, a.value, b.value);
          return (owned) x;
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
}
