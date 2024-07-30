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
  public class Clock : GLib.Object
    {
      public MainContext context { get; owned construct; }
      public Hub hub { get; construct; }
      public uint interval { get; construct; }
      private GLib.Cancellable? cancellable = null;
      private GLib.Source source;

      construct
        {
          source = new GLib.TimeoutSource (interval);

          source.set_callback (() => watch ());
          source.set_can_recurse (false);
          source.set_priority (GLib.Priority.HIGH);
          source.set_static_name ("Advertise.Clock.watch");
          source.attach (context);
        }

      public Clock (Hub hub, uint interval)
        {
          Object (context : GLib.MainContext.ref_thread_default (), hub : hub, interval : interval);
        }

      public void stop ()
        {
          source.destroy ();
        }

      private bool watch ()
        {
          cancellable?.cancel ();
          cancellable = new GLib.Cancellable ();
          hub.advertise.begin (cancellable, watch_result);
          return GLib.Source.CONTINUE;
        }

      static void watch_result (GLib.Object? source_object, GLib.AsyncResult res)
        {
          try { ((Hub) source_object).advertise.end (res); } catch (GLib.Error e)
            {
              unowned var code = e.code;
              unowned var domain = e.domain.to_string ();
              unowned var message = e.message.to_string ();

              debug ("advertise failed: %s: %i: %s", domain, code, message);
              return;
            }
        }
    }
}
