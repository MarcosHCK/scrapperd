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

[CCode (cprefix = "Scrapperd", lower_case_cprefix = "scrapperd_")]

namespace ScrapperD
{
  public abstract class Instance : GLib.Object, GLib.Initable, GLib.AsyncInitable
    {
      public const string EXTENSION_POINT = "org.hck.ScrapperD.Instance";

      public string address { get; construct; }
      public GLib.DBusConnection connection { get; private set; }
      public GLib.DBusAuthObserver? observer { get; construct; default = null; }
      public string role { get; construct; }

      private uint node_regid = 0;

      private class List<GLib.OptionEntry?> option_entries = new List<GLib.OptionEntry?> ();

      ~Instance ()
        {
          connection?.unregister_object (node_regid);
        }

      [Flags]
      private enum VersionOp
        {
          NONE = 0,
          EQUAL = (1 << 0),
          GREATER = (1 << 1),
          LESS = (1 << 2),
        }

      public virtual void activate ()
        {
          warning ("ScrapperD.Instance.activate should be overriden by implementations");
        }

      public virtual bool command_line (GLib.VariantDict dict) throws GLib.Error
        {
          return true;
        }

      public class unowned List<GLib.OptionEntry?> get_option_entries ()
        {
          return option_entries;
        }

      public bool init (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          return true;
        }

      public async override bool init_async (int io_priority, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          if (address != null)
            {
              var flags1 = GLib.DBusConnectionFlags.AUTHENTICATION_CLIENT;
              var flags2 = GLib.DBusConnectionFlags.MESSAGE_BUS_CONNECTION;
              var flags = flags1 | flags2;

              connection = yield new GLib.DBusConnection.for_address (address, flags, observer, cancellable);
              node_regid = connection.register_object<Node> (Node.BASE_PATH, Node.create (role));
            }
          return init (cancellable);
        }

      [CCode (simple_generics = false)]
      public static void install<T> (string @as, string? expected_version = null)
        {
          if (expected_version == null || version_check (expected_version))
            {
              var gtype = typeof (T);
              GLib.IOExtensionPoint.implement (EXTENSION_POINT, gtype, @as, 0);
            }
          else if (expected_version != null)
            {
              warning ("Module '%s' version requirement ('%s') could not be met\n", @as, expected_version);
            }
        }

      protected class void add_option_entry (string long_name, char short_name, GLib.OptionFlags flags, GLib.OptionArg arg, string description, string? arg_description)
        {
          var entry = GLib.OptionEntry ();

          entry.arg = arg;
          entry.arg_data = null;
          entry.arg_description = arg_description;
          entry.description = description;
          entry.flags = flags;
          entry.long_name = long_name;
          entry.short_name = short_name;
          option_entries.prepend (entry);
        }

      private static bool version_ints (string version, uint ints [3]) throws GLib.Error
        {
          unowned var from = version;
          unowned var i = 0;

          for (unichar c = 0; (c = version.get_char ()) > 0 && i < 3; version = version.next_char ())
            {
              if (c.isdigit () == true)
                {
                  from = version;
                }
              else
                {
                  unowned var length = (char*) version - (char*) from;
                  unowned var value = (uint64) 0;

                  uint64.from_string (from.substring (0, (long) length), out value, 10, 0, uint.MAX);
                  ints [i++] = (uint) value;
                }
            }

          return true;
        }

      private static unowned string version_op (string constraint, out VersionOp op)
        {
          op = VersionOp.NONE;

          for (int i = 0; i < 3; ++i) switch (constraint [i])
            {
              default: if (unlikely (i > 2)) error ("invalid version constraint '%s'", constraint); else op = i > 0 ? op : VersionOp.EQUAL;
                return constraint.offset (i);
              case '=': if (unlikely (i > 1)) error ("invalid version constraint '%s'", constraint); else op |= VersionOp.EQUAL; break;
              case '>': if (unlikely (i != 0)) error ("invalid version constraint '%s'", constraint); else op |= VersionOp.GREATER; break;
              case '<': if (unlikely (i != 0)) error ("invalid version constraint '%s'", constraint); else op |= VersionOp.LESS; break;
            }

          assert_not_reached ();
        }

      private static bool version_check (string checkstring)
        {
          uint local [3] =
            {
              Config.PACKAGE_VERSION_MAJOR,
              Config.PACKAGE_VERSION_MINOR,
              Config.PACKAGE_VERSION_MICRO,
            };

          foreach (unowned var constraint in checkstring.split (","))
            {
              unowned var op = VersionOp.NONE;
              unowned var against = version_op (constraint, out op);
              unowned var good = true;
              uint ints [3];

              try { good = version_ints (against = against.offset (against [0] != 'v' ? 0 : 1), ints); }
                catch (GLib.Error e) { good = false; } finally
                  {
                    if (unlikely (!good)) error ("invalid version constraint '%s'", constraint);
                  }

              for (int i = 0; i < ints.length; ++i)
                {
                  if (unlikely (local [i] < ints [i] && (VersionOp.LESS in op) == false)) return false;
                  else if (unlikely (local [i] == ints [i] && (VersionOp.EQUAL in op) == false)) return false;
                  else if (unlikely (local [i] > ints [i] && (VersionOp.GREATER in op) == false)) return false;
                }
            }
          return true;
        }
    }
}
