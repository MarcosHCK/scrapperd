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
using Kademlia;

[CCode (cprefix = "ScrapperdScrapper", lower_case_cprefix = "scrapperd_scrapper_")]

namespace ScrapperD.Scrapper
{
  public class Store : GLib.Object, ValueStore
    {
      public Scrapper scrapper { get; construct; }
      public ValuePeer store_peer { get; construct; }

      public Store (Scrapper scrapper, ValuePeer store_peer)
        {
          Object (scrapper : scrapper, store_peer : store_peer);
        }

      private async bool scrap_and_save (owned Key id, GLib.File uri) throws GLib.Error
        {
          var bytes = yield scrapper.scrap_uri (uri);

          debug ("uri scrapped %s:('%s')", id.to_string (), uri.get_uri ());
          return yield store_peer.insert (id, bytes);
        }

      public async override bool insert_value (Kademlia.Key id, GLib.Value? value, GLib.Cancellable? cancellable) throws GLib.Error
        {
          if (value.holds (GLib.Type.STRING) == false)

            throw new IOError.INVALID_ARGUMENT ("value should be an URI");
          else
            {
              debug ("scrapping uri %s:('%s')", id.to_string (), value.get_string ());

              var uri = GLib.File.new_for_uri (value.get_string ());
              var exists = null != yield store_peer.lookup (id, cancellable);

              if (exists)

                debug ("uri already scrapped %s:('%s')", id.to_string (), value.get_string ());
              else
                {
                  scrap_and_save.begin (id.copy (), uri, (o, res) =>
                    {
                      try { ((Store) o).scrap_and_save.end (res); } catch (GLib.Error e)
                        {
                          warning (@"$(e.domain): $(e.code): $(e.message)");
                        }
                    });
                }
              return true;
            }
        }

      public async override GLib.Value? lookup_value (Kademlia.Key id, GLib.Cancellable? cancellable) throws GLib.Error
        {
          return yield store_peer.lookup (id, cancellable);
        }
    }
}
