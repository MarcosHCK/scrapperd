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
  [Flags]

  private enum VersionOp
    {
      NONE = 0,
      EQUAL = (1 << 0),
      GREATER = (1 << 1),
      LESS = (1 << 2),
    }

  internal static bool version_check (string checkstring)
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
}
