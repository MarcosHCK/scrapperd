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
  public class Peeker : GLib.Object
    {
      public GLib.MainContext context { get; owned construct; }
      public Hub hub { get; construct; }

      public signal void got_ad (Ad ad);

      private GLib.HashTable<unowned Channel, GLib.Cancellable> cancellables;
      private GLib.HashTable<unowned Channel, GLib.Source> sources;
      private bool stopped = false;

      construct
        {
          unowned GLib.HashFunc hash_func = GLib.direct_hash;
          unowned GLib.EqualFunc key_equal_func = GLib.direct_equal;

          hub.added_channel.connect (on_added_channel);
          hub.removed_channel.connect (on_removed_channel);

          cancellables = new HashTable<unowned Channel, Cancellable> (hash_func, key_equal_func);
          sources = new HashTable<unowned Channel, Source> (hash_func, key_equal_func);

          foreach (unowned var channel in hub.channels) on_added_channel (channel);
        }

      public Peeker (Hub hub)
        {
          Object (context : MainContext.ref_thread_default (), hub : hub);
        }

      private void on_added_channel (Channel channel) requires (stopped == false)
        {
          GLib.Cancellable cancellable;
          GLib.Source source;

          cancellables.insert (channel, cancellable = new GLib.Cancellable ());
          sources.insert (channel, source = channel.create_source (cancellable));
          ((ChannelSource) source).set_callback (on_source_triggered);
          source.set_priority (GLib.Priority.DEFAULT);
          source.set_static_name ("Advertise.Peeker.channel_source");
          source.attach (context);
        }

      private void on_removed_channel (Channel channel)
        {
          GLib.Cancellable cancellable;
          GLib.Source source;

          cancellables.steal_extended (channel, null, out cancellable);
          sources.steal_extended (channel, null, out source);
          GLib.assert (cancellable != null && source != null);

          cancellable.cancel ();
          source.get_context ().iteration (false);
          source.destroy ();
        }

      private bool on_source_triggered (Channel channel)
        {
          var cancellable = (Cancellable) cancellables.lookup (channel);
          peek_channel.begin (channel, cancellable, (o,r) => on_source_triggered_result (o, r));
          return GLib.Source.CONTINUE;
        }

      private bool on_source_triggered_notify (owned GenericArray<Ad> ads)
        {
          foreach (unowned var ad in ads) got_ad (ad);
          return GLib.Source.REMOVE;
        }

      private void on_source_triggered_result (GLib.Object? o, GLib.AsyncResult res)
        {
          GenericArray<Ad> ads;

          try { ads = Hub.peek_channel.end (res); } catch (GLib.Error e)
            {
              if (e.matches (IOError.quark (), IOError.WOULD_BLOCK))

                return;
              else
                {
                  unowned var code = e.code;
                  unowned var domain = e.domain.to_string ();
                  unowned var message = e.message.to_string ();

                  debug ("advertise peek failed: %s: %i: %s", domain, code, message);
                  return;
                }
            }

          context.invoke (() => on_source_triggered_notify ((owned) ads), GLib.Priority.HIGH);
        }

      static async GenericArray<Ad> peek_channel (Channel channel, GLib.Cancellable? cancellable) throws GLib.Error
        {
          for (int i = 0; true; ++i) try
            {
              return yield Hub.peek_channel (channel, cancellable);
            }
          catch (GLib.IOError e)
            {
              if (e.code == GLib.IOError.WOULD_BLOCK && i < 2)

                continue;
              else
                throw (owned) e;
            }
        }

      public void stop ()
        {
          foreach (unowned var channel in sources.get_keys ())

            on_removed_channel (channel);
        }
    }
}
