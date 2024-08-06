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

[CCode (cprefix = "Adv", lower_case_cprefix = "adv_")]

namespace Advertise
{
  public abstract class Protocol : GLib.Object, Json.Serializable
    {
      public abstract string name { get; }
    }

  internal sealed class Protocols : GLib.Object, Json.Serializable
    {
      public string? description { get; set; }
      public string? name { get; set; }
      public GenericArray<Protocol> protocols { get; set; }

      const string default_gtype = "none";

      construct
        {
          protocols = new GenericArray<Protocol> (0);
        }

      public override bool deserialize_property (string property_name, out GLib.Value value, GLib.ParamSpec pspec, Json.Node property_node)
        {
          if (property_name != "protocols")
            {
              return default_deserialize_property (property_name, out value, pspec, property_node);
            }
          else if (unlikely (property_node.get_value_type () != typeof (Json.Array)))
            {
              value = GLib.Value (pspec.value_type);
              return false;
            }
          else
            {
              unowned var ar = property_node.get_array ();
              var list = new GenericArray<Protocol> (1 + ar.get_length ());

              foreach (unowned var element in ar.get_elements ())
                
                if (unlikely (element.get_value_type () != typeof (Json.Object)))
                  {
                    value = GLib.Value (pspec.value_type);
                    return false;
                  }
                else
                  {
                    GLib.Type gtype;
                    unowned var object = (Json.Object) element.get_object ();
                    unowned var type = (string) object.get_string_member_with_default ("gtype", default_gtype);
                    unowned var proto = (Json.Node?) object.get_member ("value");

                    if (unlikely (type == default_gtype || proto == null))
                      {
                        value = GLib.Value (pspec.value_type);
                        return false;
                      }
                    else if ((gtype = GLib.Type.from_name (type)) == GLib.Type.INVALID)
                      {
                        debug ("unknown protocol '%s'", type);
                        continue;
                      }

                    list.add ((Protocol) Json.gobject_deserialize (gtype, proto));
                  }

              (value = GLib.Value (typeof (GenericArray))).take_boxed ((owned) list);
            }
          return true;
        }

      public override Json.Node serialize_property (string property_name, GLib.Value value, GLib.ParamSpec pspec)
        {
          if (property_name != "protocols")

            return default_serialize_property (property_name, value, pspec);
          else
            {
              var array = new Json.Array ();
              var root = new Json.Node (Json.NodeType.ARRAY);

              root.set_array (array);

              foreach (unowned var proto in protocols)
                {
                  var object = new Json.Object ();

                  object.set_string_member ("gtype", proto.get_type ().name ());
                  object.set_member ("value", Json.gobject_serialize (proto));
                  array.add_object_element ((owned) object);
                }

              return (owned) root;
            }
        }
    }
}
