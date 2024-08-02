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
using Kademlia.DBus;

[CCode (cprefix = "Scrapperd", lower_case_cprefix = "scrapperd_")]

namespace ScrapperD
{
  internal class KademliaProtocol : Advertise.Protocol, Json.Serializable
    {
      public GenericArray<Address?>? addresses { get; set; }
      private Key _id;
      public Key id { get { return _id; } set { _id = value.copy (); } }
      public override string name { get { return "kademlia"; } }
      public string role { get; set; }

      public KademliaProtocol (Key id, string role, GenericArray<Address?>? addresses = null)
        {
          Object (addresses : addresses, id : id, role : role);
        }

      public bool deserialize_property (string property_name, out GLib.Value value, GLib.ParamSpec pspec, Json.Node property_node)
        {
          switch (property_name)
            {
              case "addresses":
                {
                  if (property_node.get_value_type () != typeof (Json.Array))
                    {
                      value = GLib.Value (pspec.value_type);
                      return false;
                    }
                  else
                    {
                      unowned Json.Array array = property_node.get_array ();
                      var ar = new GenericArray<Address?> (array.get_length ());

                      foreach (unowned var node in array.get_elements ())
                        {
                          if (node.get_value_type () != typeof (Json.Object))
                            {
                              value = GLib.Value (pspec.value_type);
                              return false;
                            }

                          unowned var addr = node.get_object ();

                          if (addr.get_member ("address")?.get_value_type () != typeof (string))
                            {
                              value = GLib.Value (pspec.value_type);
                              return false;
                            }

                          if (addr.get_member ("port")?.get_value_type () != typeof (int64))
                            {
                              value = GLib.Value (pspec.value_type);
                              return false;
                            }

                          unowned var address = addr.get_string_member ("address");
                          unowned var port = addr.get_int_member ("port");

                          if (port < 0 || port > uint16.MAX)
                            {
                              value = GLib.Value (pspec.value_type);
                              return false;
                            }

                          ar.add (Address (address, (uint16) port));
                        }

                      (value = GLib.Value (typeof (GenericArray))).take_boxed ((owned) ar);
                    }
                  return true;
                }

              case "id":
                {
                  if (property_node.get_value_type () != typeof (string))
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

              default: return default_deserialize_property (property_name, out value, pspec, property_node);
            }
        }

      [CCode (array_length_pos = 0.1, array_length_type = "guint")]
      public override (unowned GLib.ParamSpec)[] list_properties ()
        {
          var de = base.list_properties ();
          var ar = new (unowned GLib.ParamSpec) [de.length - 1];

          for (unowned uint i = 0, j = 0; i < de.length; ++i) if (de [i].name != "hub") ar [j++] = de [i];
          return (owned) ar;
        }

      public Json.Node serialize_property (string property_name, GLib.Value value, GLib.ParamSpec pspec)
        {
          Json.Node root;

          switch (property_name)
            {
              case "addresses":
                {
                  var array = new Json.Array ();
                  (root = new Json.Node (Json.NodeType.ARRAY)).set_array (array);

                  if (addresses != null) foreach (unowned var address in addresses)
                    {
                      var addr = new Json.Object ();

                      addr.set_string_member ("address", address.address);
                      addr.set_int_member ("port", address.port);
                      array.add_object_element ((owned) addr);
                    }
                  return (owned) root;
                }

              case "id":
                {
                  var key = ((Key) value.get_boxed ()).to_string ();
                  (root = new Json.Node (Json.NodeType.VALUE)).set_string (key);
                  return (owned) root;
                }

              default: return default_serialize_property (property_name, value, pspec);
            }
        }
    }
}
