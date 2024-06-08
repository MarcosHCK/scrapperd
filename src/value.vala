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

  public class DelegatedValue : Value
    {
      public Key[] neighbors { get; private owned set; }
      public DelegatedValue (owned Key[] neighbors) { this.neighbors = (owned) neighbors; }
    }

  public class InmediateValue<T> : Value
    {
      public T inmediate { get; private owned set; }
      public InmediateValue (T inmediate) { this.inmediate = inmediate; }
    }
  
  public class Value
    {
      [CCode (cname = "k_value_get_value", type = "gpointer")]
      public static extern unowned Value get_value ([CCode (type = "const GValue*")] GLib.Value value);
      [CCode (cname = "k_value_set_value")]
      public static extern void set_value (GLib.Value value, [CCode (type = "gpointer")] Value self);
      [CCode (cname = "k_value_take_value")]
      public static extern void take_value (GLib.Value value, [CCode (type = "gpointer")] owned Value self);
    }
}
