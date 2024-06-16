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

namespace Testing
{
  public const string TESTPATHROOT = "/org/hck/ScrapperD/Kademlia";

  public abstract class AsyncTest : GLib.Object
    {

      public void run (GLib.MainContext? context = null)
        {
          var loop = new GLib.MainLoop (context, false);

          test.begin ((o, res) =>
            {
              test.end (res);
              loop.quit ();
            });

          loop.run ();
        }

      public void run_in_thread ()
        {
          MainContext context;

          (context = new GLib.MainContext ()).push_thread_default ();
          run (context);
          context.pop_thread_default ();
        }

      protected abstract async void test ();

      public static void wait (uint[] dones)
        {
          var alpha = dones.length;
          var context = GLib.MainContext.get_thread_default ();
          var loop = new GLib.MainLoop (context, true);
          var source = new GLib.IdleSource ();

          source.set_callback (() =>
            {
              uint pending = 0;

              for (unowned var i = 0; i < alpha; ++i)
                {
                  pending |= AtomicUint.get (ref dones [i]) ^ 1;
                }

              if (pending == 0)
                {
                  loop.quit ();
                  return GLib.Source.REMOVE;
                }

              return GLib.Source.CONTINUE;
            });

          source.set_priority (GLib.Priority.HIGH_IDLE);
          source.attach (context);
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
