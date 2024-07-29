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
  [CCode (ref_function = "k_value_ref", unref_function = "k_value_unref")]
  [Compact (opaque = true)]

  public class Value
    {
      private uint refs = 1;
      private GLib.Value? _value = null;
      private Key[]? _keys = null;

      public unowned Key[] keys { get { return _keys; } }
      public unowned GLib.Value? value { get { return _value; } }

      public bool is_delegated { get { return _keys != null; } }
      public bool is_inmediate { get { return _value != null; } }

      public Value.delegated (owned Key[]? keys)
        {
          _keys = (owned) keys;
        }

      public Value.inmediate (owned GLib.Value? value)
        {
          _value = (owned) value;
        }

      public Key[] steal_keys ()
        {
          return (owned) _keys;
        }

      public GLib.Value? steal_value ()
        {
          //return (owned) _value;
          var o = GLib.Value (_value.type ());
          _value.copy (ref o);
          return (owned) o;
        }

      extern void free ();

      public unowned Value @ref ()
        {
          AtomicUint.inc (ref refs);
          return this;
        }

      public void @unref ()
        {
          if (AtomicUint.dec_and_test (ref refs))
            this.free ();
        }
    }
}
