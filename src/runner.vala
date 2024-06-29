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
  internal static void runner (GLib.MainContext? context, uint[] dones)
    {
      context = context ?? MainContext.ref_thread_default ();

      var alpha = dones.length;
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
