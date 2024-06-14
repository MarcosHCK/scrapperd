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
  public const string TESTPATHROOT = "/org/hck/ScrapperD/Kademlia";

  public abstract class AsyncTest
    {
      protected abstract async void test ();

      public void run ()
        {
          var context = (MainContext) GLib.MainContext.default ();
          var loop = new GLib.MainLoop (context, false);

          test.begin ((o, res) =>
            {
              test.end (res);
              loop.quit ();
            });

          loop.run ();
        }
    }

  [CCode (scope = "notified")]
  public delegate string ToString<T> (T item);

  public static string serialize_array<T> (T[] ar, owned ToString<T> func)
    {
      var builder = new StringBuilder ("[ ");
      var first = true;

      foreach (unowned var item in ar)
        {
          if (first)

            first = false;
          else
            builder.append (", ");
            builder.append (func (item));
        }
      builder.append (" ]");
      return builder.free_and_steal ();
    }

  public static string serialize_list<T> (GLib.List<T> list, owned ToString<T> func)
    {
      var builder = new StringBuilder ("[ ");
      var first = true;

      foreach (unowned var item in list)
        {
          if (first)

            first = false;
          else
            builder.append (", ");
            builder.append (func (item));
        }
      builder.append (" ]");
      return builder.free_and_steal ();
    }

  public static string serialize_slist<T> (GLib.SList<T> list, owned ToString<T> func)
    {
      var builder = new StringBuilder ("[ ");
      var first = true;

      foreach (unowned var item in list)
        {
          if (first)

            first = false;
          else
            builder.append (", ");
            builder.append (func (item));
        }
      builder.append (" ]");
      return builder.free_and_steal ();
    }
}
