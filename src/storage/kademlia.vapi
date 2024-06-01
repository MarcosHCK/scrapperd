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

[CCode (cheader_filename = "kademlia.h", cprefix = "K", lower_case_cprefix = "k_")]

namespace Kademlia
{
  [Compact (opaque = true)]

  public class Key
    {
      public const int BITLEN;

      public Key.from_bytes (GLib.Bytes bytes);
      public Key.from_data ([CCode (type = "gconstpointer")] void* data, size_t length);
      public Key.random ();

      public static Key copy (Key key);
      public static bool equal (Key keya, Key keyb);
      public static uint hash (Key key);
      public static unowned Key tmp ([CCode (array_length = false)] uint8[] key);

      [CCode (array_length = false, array_length_cexpr = "(K_KEY_BITLEN / 8)")]
      public unowned uint8[] get_bytes ();
      public string to_string ();
    }

  [Compact (opaque = true)] [CCode (cname = "GChecksum", has_type_id = false)]

  public class KeyBuilder
    {
      public KeyBuilder ();
      public Key end ();
      public void update (void* data, ssize_t size = -1);
    }

  public class Node : GLib.Object
    {
      public Node ();
      public Key id { get; }
      public async bool insert ([CCode (type = "const KKey*")] Key key, GLib.Bytes value, GLib.Cancellable? cancellable = null) throws GLib.Error;
      public async GLib.Bytes? lookup ([CCode (type = "const KKey*")] Key key, GLib.Cancellable? cancellable = null) throws GLib.Error;
      public GLib.SList<Key> nearest ([CCode (type = "const KKey*")] Key key);
      public signal Kademlia.Value? find_node (Key peer, Key key);
      public signal Kademlia.Value? find_value (Key peer, Key key);
      public signal bool ping (Key peer);
      public signal bool store (Key peer, Key key, GLib.Bytes value);
    }

  [Compact]
  public class Value
    {
      public uint n_neighbors;
      public bool is_delegated { get; }
      public bool is_inmediate { get; }
      private Value ();
    }

  [Compact]
  [CCode (cname = "KValue", copy_function = "k_value_copy", free_function = "k_value_free")]
  public class ValueDelegated : Value
    {
      [CCode (array_length_cname = "n_neighbors")]
      public Key[] neighbors;
      [CCode (cname = "k_value_new_delegated")]
      public ValueDelegated ([CCode (array_length_pos = 1.1)] Key[] neighbors);
    }

  [Compact]
  [CCode (cname = "KValue", copy_function = "k_value_copy", free_function = "k_value_free")]
  public class ValueInmediate : Value
    {
      public GLib.Bytes bytes;
      [CCode (cname = "k_value_new_inmediate")]
      public ValueInmediate (GLib.Bytes bytes);
    }
}
