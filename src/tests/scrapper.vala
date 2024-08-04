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
using Scrapping;

namespace Testing
{
  public static int main (string[] args)
    {
      GLib.Test.init (ref args, null);
      GLib.Test.add_func (TESTPATHROOT + "/Krypt/build", () => (new TestContentsBuilder ()).run ());
      GLib.Test.add_func (TESTPATHROOT + "/Krypt/build_incremental", () => (new TestContentsBuilder2 ()).run ());
      return GLib.Test.run ();
    }

  class TestContentsBuilder : SyncTest
    {
      public override void test ()
        {
          var builder = new ContentsBuilder ();

          builder.open_entry ();
          builder.add_html (new Bytes ("<html></html>".data));
          builder.add_link (GLib.Uri.build (0, "http", null, "localhost", -1, "/", null, null));
          builder.open_headers ();
          builder.add_header ("content-type", "text/html");
          builder.close ();
          builder.close ();
          builder.end ();
        }
    }

  class TestContentsBuilder2 : SyncTest
    {
      public override void test ()
        {
          var builder = new ContentsBuilder ();

          builder.open_entry ();
          builder.add_html (new Bytes ("<html></html>".data));
          builder.add_link (GLib.Uri.build (0, "http", null, "localhost", -1, "/index", null, null));
          builder.open_headers ();
          builder.add_header ("content-type", "text/html");
          builder.close ().close ();

          Contents contents;

          try { contents = new Contents (builder.end ()); } catch (GLib.Error e)
            {
              assert_no_error (e);
              assert_not_reached ();
            }

          var builder2 = new ContentsBuilder.incremental (contents);

          builder2.open_entry ();
          builder2.add_html (null);
          builder2.add_link (GLib.Uri.build (0, "http", null, "localhost", -1, "/image", null, null));
          builder2.open_headers ();
          builder2.add_header ("content-type", "image/png");
          builder2.close ().close ();
          builder2.end ();
        }
    }
}
