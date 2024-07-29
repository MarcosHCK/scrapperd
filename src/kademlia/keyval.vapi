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
  [CCode (cheader_filename = "keyval.h")]

  internal struct KeyVal
    {
      public const int BITLEN;
      public const GLib.ChecksumType CHECKSUM;
      [CCode (array_length_cexpr = "(G_SIZEOF_MEMBER (KKeyVal, bytes) / G_SIZEOF_MEMBER (KKeyVal, bytes [0]))")] public uint8[] bytes;
      [CCode (array_length_cexpr = "(G_SIZEOF_MEMBER (KKeyVal, shorts) / G_SIZEOF_MEMBER (KKeyVal, shorts [0]))")] public uint16[] shorts;
      [CCode (array_length_cexpr = "(G_SIZEOF_MEMBER (KKeyVal, longs) / G_SIZEOF_MEMBER (KKeyVal, longs [0]))")] public uint32[] longs;
      [CCode (array_length_cexpr = "(G_SIZEOF_MEMBER (KKeyVal, quads) / G_SIZEOF_MEMBER (KKeyVal, quads [0]))")] public uint64[] quads;
      public static bool cmp ([CCode (type = "const KKeyVal*")] KeyVal? a, [CCode (type = "const KKeyVal*")] KeyVal? b);
      public uint hash ();
      public static int log ([CCode (type = "const KKeyVal*")] KeyVal? a, [CCode (type = "const KKeyVal*")] KeyVal? b);
      public int nth_bit (uint nth);
      public static void xor (out KeyVal dst, [CCode (type = "const KKeyVal*")] KeyVal? a, [CCode (type = "const KKeyVal*")] KeyVal? b);
    }
}
