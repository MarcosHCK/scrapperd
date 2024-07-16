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
using Dh;

namespace Testing
{
  public static int main (string[] args)
    {
      GLib.Test.init (ref args, null);
      GLib.Test.add_func (TESTPATHROOT + "/DHProto/derivate", () => (new TestDerivate ()).run ());
      GLib.Test.add_func (TESTPATHROOT + "/DHProto/export", () => (new TestExport ()).run ());
      GLib.Test.add_func (TESTPATHROOT + "/DHProto/import", () => (new TestImport ()).run ());
      GLib.Test.add_func (TESTPATHROOT + "/DHProto/new", () => (new TestNew ()).run ());
      GLib.Test.add_func (TESTPATHROOT + "/DHProto/stream", () => (new TestStream ()).run ());
      return GLib.Test.run ();
    }

  class TestDerivate : SyncTest
    {
      protected override void test ()
        {
          var ni = GLib.Random.int_range (100, 1000);
          var average = (double) 0;
          var timer = new GLib.Timer ();

          for (unowned var i = 0; i < ni; ++i) try
            {
              var p1 = new PrivateSecret.generate ();
              var a1 = new PublicSecret.generate (p1);
              var p2 = new PrivateSecret.generate ();
              var a2 = new PublicSecret.generate (p2);

              timer.start ();
              var s1 = new SharedSecret (p1, a2);
              var s2 = new SharedSecret (p2, a1);
              average += timer.elapsed ();

              assert_true (SharedSecret.equals (s1, s2));

              var k1 = s1.derivate_key (128);
              var k2 = s2.derivate_key (128);
              assert_cmpmem (k1, k2);
            }
          catch (GLib.Error e)
            {
              assert_no_error (e);
              return;
            }

          GLib.Test.message ("average calculation time: %04fs", average / (double) (ni * 2));
          GLib.Test.message ("secrets calculated: %i", ni);
        }
    }

  class TestExport : TestNew
    {
      protected Bytes[] exporteds;

      protected override void test ()
        {
          base.test ();
          var ni = publics.length;
          var average = (double) 0;
          var timer = new GLib.Timer ();

          exporteds = new Bytes [ni];

          for (unowned var i = 0; i < ni; ++i)
            {
              timer.start ();

              try { exporteds [i] = publics [i].get_data_as_bytes (); average += timer.elapsed (); } catch (GLib.Error e)
                {
                  assert_no_error (e);
                }
            }

          GLib.Test.message ("average export time: %04fs", average / (double) ni);
          GLib.Test.message ("secrets exported: %i", ni);
        }
    }

  class TestImport : TestExport
    {
      protected override void test ()
        {
          base.test ();
          var ni = exporteds.length;
          var average = (double) 0;
          var timer = new GLib.Timer ();

          for (unowned var i = 0; i < ni; ++i)
            {
              PublicSecret cur;
              timer.start ();

              try { cur = new PublicSecret.from_buffer (exporteds [i].get_data ()); average += timer.elapsed (); } catch (GLib.Error e)
                {
                  assert_no_error (e);
                  break;
                }

              assert_true (PublicSecret.equals (cur, publics [i]));
            }

          GLib.Test.message ("average import time: %04fs", average / (double) ni);
          GLib.Test.message ("secrets imported: %i", ni);
        }
    }

  class TestNew : SyncTest
    {
      protected Dh.PrivateSecret[] privates;
      protected Dh.PublicSecret[] publics;

      protected override void test ()
        {
          var ni = GLib.Random.int_range (100, 1000);

          var average = (double) 0;
          var timer = new GLib.Timer ();

          privates = new Dh.PrivateSecret [ni];
          publics = new Dh.PublicSecret [ni];

          for (unowned var i = 0; i < ni; ++i)
            {
              timer.start ();

              try
                {
                  privates [i] = new Dh.PrivateSecret.generate ();
                  publics [i] = new Dh.PublicSecret.generate (privates [i]);
                  average += timer.elapsed ();
                }
              catch (GLib.Error e)
                {
                  assert_no_error (e);
                }
            }

          GLib.Test.message ("average create time: %04fs", average / (double) ni);
          GLib.Test.message ("secret pairs created: %i", ni);
        }
    }

  class TestStream : AsyncTest
    {
      protected override async void test ()
        {
          var ni = GLib.Random.int_range (100, 1000);
          var average = (double) 0;
          var timer = new GLib.Timer ();

          for (unowned var i = 0; i < ni; ++i) try
            {
              var private_secret = new PrivateSecret.generate ();
              var public_secret = new PublicSecret.generate (private_secret);
              var line = Base64.encode (public_secret.get_data ());

              var istream = new MemoryInputStream.from_data ((line + "\n").data);
              var ostream = new MemoryOutputStream.resizable ();
              var stream = new TestStreamImpl (new SimpleIOStream (istream, ostream));
              timer.start ();

              yield stream.handshake_server (GLib.Priority.DEFAULT);
              average += timer.elapsed ();
            }
          catch (GLib.Error e)
            {
              assert_no_error (e);
              return;
            }

          GLib.Test.message ("average handshake time: %04fs", average / (double) ni);
          GLib.Test.message ("handshakes done: %i", ni);
        }
    }

  class TestStreamImpl : Dh.IOStream
    {
      public override GLib.InputStream input_stream { get { return base_stream.input_stream; } }
      public override GLib.OutputStream output_stream { get { return base_stream.output_stream; } }

      public TestStreamImpl (GLib.IOStream base_stream)
        {
          Object (base_stream : base_stream);
        }
    }
}
