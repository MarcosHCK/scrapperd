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
using Scrapping;

[CCode (cprefix = "ScrapperdScrapper", lower_case_cprefix = "scrapperd_scrapper_")]

namespace ScrapperD.Scrapper
{
  public class Store : GLib.Object, ValueStore
    {
      public Scrapping.Scrapper scrapper { get; construct; }
      private WeakRef _scrapper_peer;
      public ValuePeer scrapper_peer { owned get { return (ValuePeer) _scrapper_peer.get (); } set { _scrapper_peer.set (value); } }
      private WeakRef _store_peer;
      public ValuePeer store_peer { owned get { return (ValuePeer) _store_peer.get (); } set { _store_peer.set (value); } }

      public Store (Scrapping.Scrapper scrapper)
        {
          Object (scrapper : scrapper);
        }

      public override async Key[] enumerate_staled_values (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          return new Key [0];
        }

      private async void scrap_and_save (owned Key id, GLib.Uri uri, owned GLib.Value? other) throws GLib.Error

          requires (other == null || other.holds (typeof (GLib.Bytes)))
        {
          Contents? contents = null;

          if (other != null && (contents = new Scrapping.Contents.from_bytes ((Bytes) other)).contains (uri))

            debug ("uri already scrapped %s:('%s')", id.to_string (), uri.to_string ());
          else if (other == null)
            {
              Scrapping.Result? result;

              try { result = yield scrapper.scrap_uri (uri); } catch (GLib.Error e)
                {
                  unowned var domain = e.domain.to_string ();
                  unowned var code = e.code;
                  unowned var message = e.message;

                  debug ("could not scrap uri (%s: %i: %s) %s:('%s')", domain, code, message, id.to_string (), uri.to_string ());
                  return;
                }

              debug ("uri scrapped %s:('%s')", id.to_string (), uri.to_string ());

              var builder = (ContentsBuilder) (other == null ? new ContentsBuilder () : new ContentsBuilder.incremental (contents));
              var iter = new GLib.VariantIter (result.content);
              var variant = (GLib.Variant?) null;

              while ((variant = iter.next_value ()) != null)

                builder.add_value (variant);

              if (unlikely (false == yield store_peer.insert (id, builder.end ().get_data_as_bytes ())))
                {
                  debug ("uri data was not saved %s:('%s')", id.to_string (), uri.to_string ());
                }
              else foreach (unowned var link in result.links)
                {
                  var uri_string = (string?) null;
                  var child = Scrapping.normalize_uri (link);
                  var child_id = new Key.from_data ((uri_string = child.to_string ()).data);

                  debug ("found link in uri '%s' <= %s:('%s')", child.to_string (), id.to_string (), uri.to_string ());
                  yield scrapper_peer.insert (child_id, uri_string);
                }
            }
        }

      public async bool insert_value (Kademlia.Key id, GLib.Value? value, GLib.Cancellable? cancellable) throws GLib.Error
        {
          GLib.Value? other;
          GLib.Uri uri;

          if (value.holds (typeof (string)) == false)
            {
              throw new IOError.INVALID_ARGUMENT ("value should be an URI");
            }
          else if (Scrapping.uri_is_valid (uri = Scrapping.normal_uri (value.get_string ())) == false)
            {
              debug ("invalid HTTP uri %s:('%s')", id.to_string (), uri.to_string ());
              return false;
            }
          else
            {
              debug ("scrapping uri %s:('%s')", id.to_string (), uri.to_string ());
              other = yield store_peer.lookup (id, cancellable);

              scrap_and_save.begin (id.copy (), uri, (owned) other, (o, res) =>
                {
                  try { ((Store) o).scrap_and_save.end (res); } catch (GLib.Error e)
                    {
                      warning (@"$(e.domain): $(e.code): $(e.message)");
                    }
                });
              return true;
            }
        }

      public async GLib.Value? lookup_value (Kademlia.Key id, GLib.Cancellable? cancellable) throws GLib.Error
        {
          return yield store_peer.lookup (id, cancellable);
        }
    }
}
