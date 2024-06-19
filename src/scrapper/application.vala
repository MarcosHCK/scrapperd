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
using KademliaDBus;

[CCode (cprefix = "ScrapperdScrapper", lower_case_cprefix = "scrapperd_scrapper_")]

namespace ScrapperD.Scrapper
{
  const string APPID = "org.hck.ScrapperD.Scrapper";

  public sealed class Application : ScrapperD.Application
    {
      private Scrapper? scrapper = null;
      private Store? store = null;

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

              foreach (unowned var arg in cmdline.get_arguments ()) if (first) first = false; else
                {
                  var value = (string?) null;
                  var file = cmdline.create_file_for_arg (arg);
                  var id = new Kademlia.Key.from_data ((value = file.get_uri ()).data);

                  try { yield store.insert_value (id, value, cancellable); } catch (GLib.Error e)
                    {
                      warning (@"$(e.domain): $(e.code): $(e.message)");
                    }
                }
            }

          return good;
        }

      protected override async bool register_on_hub_async () throws GLib.Error
        {
          var store_peer = new PeerImplProxy ("storage");

          hub.add_peer (store_peer);
          hub.add_peer (new PeerImpl ("scrapper", store = new Store (scrapper, store_peer)));
          return true;
        }
    } 
}
