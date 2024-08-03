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
      private WeakRef _scrapper_peer;
      public ValuePeer scrapper_peer { owned get { return (ValuePeer) _scrapper_peer.get (); } set { _scrapper_peer.set (value); } }
      private WeakRef _store_peer;
      public ValuePeer store_peer { owned get { return (ValuePeer) _store_peer.get (); } set { _store_peer.set (value); } }

      public Store (Scrapper scrapper)
        {
          Object (scrapper : scrapper);
        }

      public override async Key[] enumerate_staled_values (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          return new Key [0];
        }

      private async void scrap_and_save (owned Key id, GLib.Uri uri, owned GLib.Value? otherv) throws GLib.Error

          requires (otherv == null || otherv.holds (typeof (GLib.Bytes)))
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

          GLib.Variant contents;

          if (otherv == null)
            {
              Variant arv [1] = { result.content };
              contents = new Variant.array (null, arv);
            }
          else
            {
              var type = new VariantType.array (Scrapper.scrap_variant_type);
              var other = new Variant.from_bytes (type, (Bytes) otherv.get_boxed (), false);
              var builder = new VariantBuilder (type);
              var iter = new VariantIter (other);
              var child = (GLib.Variant?) null;

              while ((child = iter.next_value ()) != null)

                builder.add_value (child);
                builder.add_value (result.content);

              contents = builder.end ();
            }

          if (unlikely (false == yield store_peer.insert (id, contents.get_data_as_bytes ())))
            {
              debug ("uri data was not saved %s:('%s')", id.to_string (), uri.to_string ());
            }
          else foreach (unowned var link in result.links)
            {
              var uri_string = (string?) null;
              var child = Scrapper.normalize_uri (link);
              var child_id = new Key.from_data ((uri_string = child.to_string ()).data);

              debug ("found link in uri '%s' <= %s:('%s')", child.to_string (), id.to_string (), uri.to_string ());
              yield scrapper_peer.insert (child_id, uri_string);
            }
        }

      public async bool insert_value (Kademlia.Key id, GLib.Value? value, GLib.Cancellable? cancellable) throws GLib.Error
        {
          if (value.holds (typeof (string)) == false)

            throw new IOError.INVALID_ARGUMENT ("value should be an URI");
          else
            {
              var uri = (Uri) Scrapper.normal_uri (value.get_string ());
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
