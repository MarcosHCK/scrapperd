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

[CCode (cprefix = "ScrapperdScrapper", lower_case_cprefix = "scrapperd_scrapper_")]

namespace ScrapperD.Scrapper
{
  const string APPID = "org.hck.ScrapperD.Scrapper";

  public sealed class Application : ScrapperD.Application
    {
      private Scrapper? scrapper = null;
      private Store? store = null;
      private Object? store_proxy = null;

      construct
        {
          scrapper = new Scrapper ();
        }

      public Application ()
        {
          base (APPID, GLib.ApplicationFlags.NON_UNIQUE);
        }

      public static int main (string[] argv)
        {
          return (new Application ()).run (argv);
        }

      protected override async bool command_line_async (GLib.ApplicationCommandLine cmdline, GLib.Cancellable? cancellable = null)
        {
          bool good;

          if (likely (good = yield base.command_line_async (cmdline, cancellable)))
            {
              assert (store != null);
              bool first = true;

              try { store_proxy = yield hub.create_proxy ("storage", cancellable); } catch (GLib.Error e)
                {
                  good = false;
                  cmdline.printerr ("can not connect to network: %s: %u: %s", e.domain.to_string (), e.code, e.message);
                  cmdline.set_exit_status (1);
                  return false;
                }

              store.store_peer = (Kademlia.ValuePeer) store_proxy;

              foreach (unowned var uri_string in cmdline.get_arguments ()) if (first) first = false; else try
                {
                  var value = (string?) null;
                  var uri = (Uri) Scrapper.normal_uri (uri_string);
                  var id = new Kademlia.Key.from_data ((value = uri.to_string ()).data);

                  try { yield store.insert_value (id, new Bytes (value.data), cancellable); } catch (GLib.Error e)
                    {
                      good = false;
                      cmdline.printerr ("can not scrap uri: %s: %u: %s", e.domain.to_string (), e.code, e.message);
                      cmdline.set_exit_status (1);
                      break;
                    }
                }
              catch (GLib.UriError e)
                {
                  good = false;
                  cmdline.printerr ("can not parse uri '%s': %s: %u: %s", uri_string, e.domain.to_string (), e.code, e.message);
                  cmdline.set_exit_status (1);
                  break;
                }
            }

          return good;
        }

      protected override async void register_peers () throws GLib.Error
        {
          var value_store = new Store (scrapper);
          var scrapper_peer = new Kademlia.DBus.PeerImpl (value_store);

          hub.add_local_peer ("scrapper", scrapper_peer);
          (store = value_store).scrapper_peer = scrapper_peer;
        }
    } 
}
