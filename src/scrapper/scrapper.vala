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
  public class Scrapper : GLib.Object
    {
      public Soup.Session session { get; construct; }

      public static GLib.VariantType scrap_variant_type = new GLib.VariantType ("(maysa{ss})");
      private static GLib.VariantType scrap_variant_bytestring_type = new GLib.VariantType ("ay");
      private static GLib.VariantType scrap_variant_dictionary_type = new GLib.VariantType ("a{ss}");

      [Compact] public class Result
        {
          public GLib.Bytes contents;
          public GLib.SList<GLib.Uri> links;

          public Result (GLib.Bytes contents, owned SList<Uri> links)
            {
              this.contents = contents;
              this.links = (owned) links;
            }
        }

      construct
        {
          session = new Soup.Session ();

          session.set_accept_language_auto (true);
          session.set_user_agent (Config.PACKAGE_STRING);
        }

      static void annotate (GLib.VariantBuilder builder, Soup.MessageHeaders headers, string name, string? @as = null)
        {
          string? value;

          if ((value = headers.get_one (name)) != null)
            {
              builder.add ("{ss}", @as ?? name, value);
            }
        }

      static GLib.Bytes finish (GLib.VariantBuilder builder)
        {
          uint8[] buffer;
          GLib.Variant result;

          result = builder.end ();
          result.store (buffer = new uint8 [result.get_size ()]);
          return new Bytes.take ((owned) buffer);
        }

      [CCode (cheader_filename = "validuri.h", cname = "_g_uri_is_valid")]

      internal static extern bool uri_is_valid (GLib.Uri uri);

      public static GLib.Uri normal_uri (string uri_string) throws GLib.UriError
        {
          var flags1 = GLib.UriFlags.ENCODED;
          var flags2 = GLib.UriFlags.SCHEME_NORMALIZE;
          var flags = flags1 | flags2;
          return Uri.parse (uri_string, flags);
        }

      public static GLib.Uri normalize_uri (GLib.Uri uri)
        {
          var flags1 = GLib.UriHideFlags.AUTH_PARAMS;
          var flags2 = GLib.UriHideFlags.FRAGMENT;
          var flags3 = GLib.UriHideFlags.PASSWORD;
          var flags4 = GLib.UriHideFlags.USERINFO;
          var flags = flags1 | flags2 | flags3 | flags4;
          var uri_string = uri.to_string_partial (flags);

          try { return Uri.parse (uri_string, GLib.UriFlags.ENCODED); } catch (GLib.Error e)
            {
              error (@"$(e.domain): $(e.code): $(e.message)");
            }
        }

      public async Result? scrap_uri (owned GLib.Uri uri, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var message = new Soup.Message.from_uri ("GET", uri);
          var stream = yield session.send_async (message, GLib.Priority.LOW, cancellable);

          var builder = new VariantBuilder (scrap_variant_type);
          var links = new GLib.SList<GLib.Uri> ();
          var ratio = (double) (-1.0);
          var response_headers = message.get_response_headers ();

          if (! GLib.ContentType.equals ("text/html", response_headers.get_content_type (null)))
            {
              yield stream.close_async (GLib.Priority.LOW, cancellable);
              builder.add_value (new GLib.Variant.maybe (scrap_variant_bytestring_type, null));
            }
          else
            {
              var searcher = new LinkSearcherConverter ();
              var zlib = new GLib.ZlibCompressor (GLib.ZlibCompressorFormat.ZLIB, 9);

              var searcher_stream = new GLib.ConverterInputStream (stream, searcher);
              var zlib_stream = new GLib.ConverterInputStream (searcher_stream, zlib);
              var bytes_stream = new GLib.MemoryOutputStream.resizable ();

              searcher_stream.close_base_stream = true;
              zlib_stream.close_base_stream = true;

              var splice_flags1 = GLib.OutputStreamSpliceFlags.CLOSE_SOURCE;
              var splice_flags2 = GLib.OutputStreamSpliceFlags.CLOSE_TARGET;
              var splice_flags = splice_flags1 | splice_flags2;

              var read = yield bytes_stream.splice_async (zlib_stream, splice_flags, GLib.Priority.LOW, cancellable);

              var bytes = bytes_stream.steal_as_bytes ();
              var hrefs = searcher.steal_hrefs ();

              ratio = read >= ssize_t.MAX ? -1 : (double) read / (double) response_headers.get_content_length ();

              foreach (unowned var href in hrefs) try
                {
                  unowned var uri_flags1 = GLib.UriFlags.ENCODED;
                  unowned var uri_flags2 = GLib.UriFlags.SCHEME_NORMALIZE;
                  unowned var uri_flags = uri_flags1 | uri_flags2;

                  links.prepend (Uri.parse_relative (uri, href, uri_flags));
                }
              catch (GLib.UriError e)
                {
                  warning ("can not parse uri '%s': %s: %u: %s", href, e.domain.to_string (), e.code, e.message);
                }

              var child = new GLib.Variant.from_bytes (scrap_variant_bytestring_type, bytes, false);
              var container = new GLib.Variant.maybe (scrap_variant_bytestring_type, child);
              builder.add_value (container);
            }

          builder.add_value (new GLib.Variant.string (uri.to_string ()));
          builder.open (scrap_variant_dictionary_type);

          if (ratio >= 0)
            {
              char buffer [double.DTOSTR_BUF_SIZE];
              builder.add ("{ss}", "ratio", ratio.to_str (buffer));
            }

          annotate (builder, response_headers, "Content-Type", "content-type");
          annotate (builder, response_headers, "Date", "date");
          annotate (builder, response_headers, "Server", "server");
          builder.close ();

          return new Result (finish (builder), (owned) links);
        }
    }
}
