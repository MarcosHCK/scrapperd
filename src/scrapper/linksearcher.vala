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
  public class RateConstraintConverter : GLib.Object, GLib.Converter
    {
      public size_t max_bytes { get; construct; }

      public RateConstraintConverter (size_t max_bytes)
        {
          Object (max_bytes : max_bytes);
        }

      public GLib.ConverterResult convert (uint8[] inbuf, uint8[] outbuf, GLib.ConverterFlags flags, out size_t bytes_read, out size_t bytes_written) throws GLib.Error
        {
          size_t copied;

          Memory.copy (& outbuf [0], & inbuf [0], copied = size_t.min (max_bytes, size_t.min (inbuf.length, outbuf.length)));
          bytes_read = bytes_written = copied;

          return (flags & (ConverterFlags.FLUSH | ConverterFlags.INPUT_AT_END)) == 0 ? ConverterResult.CONVERTED : ((flags & (ConverterFlags.INPUT_AT_END)) == 0 ? ConverterResult.FLUSHED : ConverterResult.FINISHED);
        }

      public void reset ()
        {
        }
    }

  public class LinkSearcherConverter : GLib.Object, GLib.Converter
    {
      private GLib.SList<string> hrefs;
      private GLib.Regex[] regexes;

      construct
        {
          hrefs = new SList<string> ();

          var compile_options1 = GLib.RegexCompileFlags.MULTILINE;
          var compile_options2 = GLib.RegexCompileFlags.OPTIMIZE;
          var compile_options3 = GLib.RegexCompileFlags.RAW;
          var compile_options = compile_options1 | compile_options2 | compile_options3;

          var match_options1 = GLib.RegexMatchFlags.NOTEMPTY;
          var match_options2 = GLib.RegexMatchFlags.PARTIAL_HARD;
          var match_options = match_options1 | match_options2;

          try
            {
              regexes =
                {
                  new GLib.Regex ("<a[^>h]*href\\s*=\\s*\"([^\"]+)\"[^>]*>", compile_options, match_options),
                  new GLib.Regex ("<a[^/h]*href\\s*=\\s*\"([^\"]+)\"[^/]*/>", compile_options, match_options),
                };
            }
          catch (GLib.Error e)
            {
              error (@"$(e.domain): $(e.code): $(e.message)");
            }
        }

      static size_t migrate (uint8[] inbuf, uint8[] outbuf)
        {
          size_t copied;
          Memory.copy (& outbuf [0], & inbuf [0], copied = size_t.min (inbuf.length, outbuf.length));
          return copied;
        }

      static GLib.ConverterResult result_from_flags (GLib.ConverterFlags flags)
        {
          var flush = 0 != (flags & GLib.ConverterFlags.FLUSH);
          var input_at_end = 0 != (flags & GLib.ConverterFlags.INPUT_AT_END);
          return !(flush || input_at_end) ? ConverterResult.CONVERTED : (!input_at_end ? ConverterResult.FLUSHED : ConverterResult.FINISHED);
        }

      public GLib.ConverterResult convert (uint8[] inbuf, uint8[] outbuf, GLib.ConverterFlags converter_flags, out size_t bytes_read, out size_t bytes_written) throws GLib.Error
        {
          GLib.MatchInfo? info;
          unowned var input_ = (string) inbuf;

          bytes_read = bytes_written = 0;

          foreach (unowned var regex in regexes)
            {
              regex.match_full (input_, inbuf.length, 0, 0, out info);

              if (info != null)
                {
                  if (info.is_partial_match ())
                    {
                      if ((converter_flags & (ConverterFlags.FLUSH | ConverterFlags.INPUT_AT_END)) == 0)

                        throw new IOError.PARTIAL_INPUT ("partial match, give me more data to find whole link");
                    }
                  else for (unowned var i = 0; info.matches (); ++i)
                    {
                      hrefs.prepend (info.fetch (1));
                      info.next ();
                    }
                }
            }

          bytes_read = bytes_written = migrate (inbuf, outbuf);

          return result_from_flags (converter_flags);
        }

      public void reset ()
        {
        }

      public GLib.SList<string> steal_hrefs ()
        {
          var hrefs_ = (owned) hrefs;
            hrefs = new GLib.SList<string> ();
          return (owned) hrefs_;
        }
    }
}
