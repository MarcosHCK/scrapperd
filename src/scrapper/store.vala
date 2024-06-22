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

      private WeakRef _scrapper_peer;
      public ValuePeer scrapper_peer { owned get { return (ValuePeer) _scrapper_peer.get (); } set { _scrapper_peer.set (value); } }

      public Store (Scrapper scrapper, ValuePeer store_peer)
        {
          Object (scrapper : scrapper, store_peer : store_peer);
        }

      private async void scrap_and_save (owned Key id, GLib.Uri uri, GLib.Bytes? other) throws GLib.Error
        {
          Scrapper.Result? result = null;

          try { result = yield scrapper.scrap_uri (uri); } catch (GLib.Error e)
            {
              unowned var domain = e.domain.to_string ();
              unowned var code = e.code;
              unowned var message = e.message;

              debug ("could not scrap uri (%s: %i: %s) %s:('%s')", domain, code, message, id.to_string (), uri.to_string ());
              return;
            }

          debug ("uri scrapped %s:('%s')", id.to_string (), uri.to_string ());

          GLib.Bytes contents;

          if (other == null)

            contents = result.contents;
          else
            {
              var otherv = new GLib.Variant.from_bytes (Scrapper.scrap_variant_type, other, false);
              var arv = (GLib.Variant) null;

              if (otherv.is_of_type (GLib.VariantType.ARRAY) == false)
                {
                  GLib.Variant newv;

                  newv = new GLib.Variant.from_bytes (Scrapper.scrap_variant_type, result.contents, false);
                  arv = new GLib.Variant.array (Scrapper.scrap_variant_type, { otherv, newv });
                }
              else
                {
                  var othern = arv.n_children ();
                  var othervs = new GLib.Variant [1 + othern];
                  var i = 0;

                  foreach (var child in otherv)
                    {
                      othervs [++i] = (owned) child;
                    }

                  othervs [0] = new GLib.Variant.from_bytes (Scrapper.scrap_variant_type, result.contents, false);
                  arv = new GLib.Variant.array (Scrapper.scrap_variant_type, othervs);
                }

              var data = new uint8 [arv.get_size ()];

              arv.store (& data [0]);
              contents = new GLib.Bytes.take (data);
            }

          if (unlikely (false == yield store_peer.insert (id, contents)))

            debug ("uri data was not saved %s:('%s')", id.to_string (), uri.to_string ());

          foreach (unowned var link in result.links)
            {
              var uri_string = (string?) null;
              var child = Scrapper.normalize_uri (link);
              var child_id = new Key.from_data ((uri_string = child.to_string ()).data);

              debug ("found link in uri '%s' <= %s:('%s')", child.to_string (), id.to_string (), uri.to_string ());
              yield scrapper_peer.insert (child_id, new GLib.Bytes (uri_string.data));
            }
        }

      public async override bool insert_value (Kademlia.Key id, GLib.Value? value, GLib.Cancellable? cancellable) throws GLib.Error
        {
          if (value.holds (typeof (GLib.Bytes)) == false)

            throw new IOError.INVALID_ARGUMENT ("value should be an URI");
          else
            {
              unowned var uri_bytes = (Bytes) value.get_boxed ();
              unowned var uri_string = (string) uri_bytes.get_data ();

              var uri = (Uri) Scrapper.normal_uri (uri_string.substring (0, (long) uri_bytes.get_size ()));
              var other = (GLib.Value?) null;

              if (Scrapper.uri_is_valid (uri) == false)
                {
                  debug ("invalid HTTP uri %s:('%s')", id.to_string (), uri.to_string ());
                  return false;
                }

              debug ("scrapping uri %s:('%s')", id.to_string (), uri.to_string ());

              if (null != (other = yield store_peer.lookup (id, cancellable)))

                debug ("uri already scrapped %s:('%s')", id.to_string (), uri.to_string ());
              else

                scrap_and_save.begin (id.copy (), uri, (Bytes?) other?.get_boxed (), (o, res) =>
                  {
                    try { ((Store) o).scrap_and_save.end (res); } catch (GLib.Error e)
                      {
                        warning (@"$(e.domain): $(e.code): $(e.message)");
                      }
                  });
              return true;
            }
        }

      public async override GLib.Value? lookup_value (Kademlia.Key id, GLib.Cancellable? cancellable) throws GLib.Error
        {
          return yield store_peer.lookup (id, cancellable);
        }
    }
}
