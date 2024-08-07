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

[CCode (cprefix = "KDBus", lower_case_cprefix = "k_dbus_")]

namespace Kademlia.DBus
{
  internal class Clock : GLib.Object
    {
      public const uint CLOCK_TICK_TIME = 300;
      public GLib.Cancellable cancellable { get; construct; }
      public GLib.MainContext context { get; construct; }
      public Hub hub { owned get { return (Hub) _hub.get (); } set { _hub.set (value); } }
      public GLib.Source source { get; construct; }

      private Mutex peer_mutex = Mutex ();
      private Mutex value_mutex = Mutex ();
      private WeakRef _hub;

      construct
        {
          static_assert (CLOCK_TICK_TIME < Buckets.FIRSTSTALETIME);
          static_assert (CLOCK_TICK_TIME < Buckets.MAXSLEEPTIME);

          cancellable = new GLib.Cancellable ();
          source = new GLib.TimeoutSource (CLOCK_TICK_TIME);

          source.set_callback (watch);
          source.set_priority (GLib.Priority.DEFAULT_IDLE);
          source.set_static_name ("Kademlia.DBus.Hub.clock");
          source.attach (context);
        }

      public Clock (Hub hub)
        {
          Object (context : MainContext.ref_thread_default (), hub : hub);
        }

      public void destroy ()
        {
          cancellable.cancel ();
          source.destroy ();
          context.iteration (false);
        }

      private async void peer_step (Hub hub, Cancellable? cancellable = null) throws GLib.Error
        {
          var locals = new GLib.List<PeerImpl> ();
          hub.foreach_local ((a, b, peer) => locals.append (peer));

          foreach (unowned var peer in locals)
            {
              yield peer.check_dormat_ranges (cancellable);
              yield peer.check_stale_contacts (cancellable);
            }
        }

      private async void value_step (Hub hub, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var locals = new GLib.List<PeerImpl> ();
          hub.foreach_local ((a, b, peer) => locals.append (peer));

          foreach (unowned var peer in locals) foreach (unowned var key in yield peer.value_store.enumerate_staled_values (cancellable))
            {
              GLib.Value? value;

              if ((value = yield peer.value_store.lookup_value (key, cancellable)) != null)

                yield peer.insert (key, (owned) value, cancellable);
            }
        }

      private bool watch ()
        {
          Hub hub;

          if ((hub = _hub.get () as Hub) != null)
            {
              if (peer_mutex.trylock ())

                peer_step.begin (hub, cancellable, (o, res) =>
                  {
                    try { ((Clock) o).peer_step.end (res); } catch (GLib.Error e)
                      {
                        unowned var code = e.code;
                        unowned var domain = e.domain.to_string ();
                        unowned var message = e.message.to_string ();

                        warning ("hub clock error: %s: %u: %s", domain, code, message);
                      }

                    peer_mutex.unlock ();
                  });

              if (value_mutex.trylock ())

                value_step.begin (hub, cancellable, (o, res) =>
                  {
                    try { ((Clock) o).value_step.end (res); } catch (GLib.Error e)
                      {
                        unowned var code = e.code;
                        unowned var domain = e.domain.to_string ();
                        unowned var message = e.message.to_string ();

                        warning ("hub clock error: %s: %u: %s", domain, code, message);
                      }

                    value_mutex.unlock ();
                  });
            }
          return GLib.Source.CONTINUE;
        }
    }
}
