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

[CCode (cprefix = "Scrapperd", lower_case_cprefix = "scrapperd_")]

namespace ScrapperD
{
  internal class KademliaProtocol : Advertise.Protocol, Json.Serializable
    {
      private Key _id;
      public Key id { get { return _id; } set { _id = value.copy (); } }
      public override string name { get { return "kademlia"; } }

      public KademliaProtocol (Key id)
        {
          Object (id : id);
        }

      public bool deserialize_property (string property_name, out GLib.Value value, GLib.ParamSpec pspec, Json.Node property_node)
        {
          if (property_name != "id")

            return default_deserialize_property (property_name, out value, pspec, property_node);
          else if (property_node.get_value_type () != typeof (string))
            {
              value = GLib.Value (pspec.value_type);
              return false;
            }
          else
            {
              unowned string str = property_node.get_string ();
              Key key;

              try { key = new Key.parse (str, -1); } catch (GLib.Error e)
                {
                  unowned var code = e.code;
                  unowned var domain = e.domain.to_string ();
                  unowned var message = e.message.to_string ();
                  value = GLib.Value (pspec.value_type);

                  warning ("failed key deserialization: %s: %u: %s", domain, code, message);
                  return false;
                }

              (value = GLib.Value (typeof (Key))).take_boxed ((owned) key);
            }
          return true;
        }

      public Json.Node serialize_property (string property_name, GLib.Value value, GLib.ParamSpec pspec)
        {
          if (property_name != "id")

            return default_serialize_property (property_name, value, pspec);
          else
            {
              var key = ((Key) value.get_boxed ()).to_string ();
              var str = new Json.Node (Json.NodeType.VALUE);
                str.set_string (key);
              return str;
            }
        }
    }
}
