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
using Krypt;

namespace Testing
{
  public static int main (string[] args)
    {
      GLib.Test.init (ref args, null);
      GLib.Test.add_func (TESTPATHROOT + "/Krypt/stream_splice", () => (new TestStreamSplice ()).run ());
      GLib.Test.add_func (TESTPATHROOT + "/Krypt/stream_write", () => (new TestStreamWrite ()).run ());
      return GLib.Test.run ();
    }

  class TestStreamSplice : AsyncTest
    {
      protected const string algo_name = "AES";
      protected const string mode_name = "CBC";

      protected const uint ns_minsize = 100;
      protected const uint ns_maxsize = ns_minsize * 10;
      protected const uint vector_minsize = 3000;
      protected const uint vector_maxsize = vector_minsize * 10;

      protected static GLib.Bytes random_bytes_vector (uint minsize, uint maxsize)
        {
          var size = GLib.Test.rand_int_range ((int32) minsize, (int32) maxsize);
          var data = new uint8 [size];

          for (int i = 0; i < size; ++i) data [i] = (uint8) GLib.Test.rand_int_range (0, uint8.MAX);
          return new GLib.Bytes.take ((owned) data);
        }

      protected override async void test ()
        {
          var tt = (size_t) 0;
          var ns = (int) GLib.Test.rand_int_range ((int) ns_minsize, (int) ns_maxsize);

          var average = (double) 0;
          var timer = new GLib.Timer ();

          for (int i = 0; i < ns; ++i)
            {
              Krypt.IOStream stream1, stream2;
              var vector1 = random_bytes_vector (vector_minsize, vector_maxsize);
              var vector2 = random_bytes_vector (vector_minsize, vector_maxsize);
              tt += vector1.length + vector2.length;

              var flags = (IOStreamSpliceFlags) GLib.IOStreamSpliceFlags.WAIT_FOR_BOTH;
              var stream1_input = new GLib.MemoryInputStream.from_bytes (vector1);
              var stream1_output = new GLib.MemoryOutputStream.resizable ();
              var stream2_input = new GLib.MemoryInputStream.from_bytes (vector2);
              var stream2_output = new GLib.MemoryOutputStream.resizable ();

              try { stream1 = new Krypt.IOStream (algo_name, mode_name, new GLib.SimpleIOStream (stream1_input, stream1_output)); } catch (GLib.Error e)
                {
                  assert_no_error (e);
                  return;
                }

              try { stream2 = new Krypt.IOStream (algo_name, mode_name, new GLib.SimpleIOStream (stream2_input, stream2_output)); } catch (GLib.Error e)
                {
                  assert_no_error (e);
                  return;
                }

              try
                {
                  Krypt.Bc.DecryptConverter decrypter1, decrypter2;
                  Krypt.Bc.EncryptConverter encrypter1, encrypter2;

                  var private_secret = new Krypt.Dh.PrivateSecret.generate ();
                  var public_secret = new Krypt.Dh.PublicSecret.generate (new Krypt.Dh.PrivateSecret.generate ());
                  var shared_secret = new Krypt.Dh.SharedSecret (private_secret, public_secret);

                  stream1.input_stream.get ("converter", out decrypter1);
                  stream1.output_stream.get ("converter", out encrypter1);
                  stream2.input_stream.get ("converter", out decrypter2);
                  stream2.output_stream.get ("converter", out encrypter2);

                  decrypter1.set_key (shared_secret.derivate_key (decrypter1.keylen << 3));
                  decrypter2.set_key (shared_secret.derivate_key (decrypter2.keylen << 3));
                  encrypter1.set_key (shared_secret.derivate_key (encrypter1.keylen << 3));
                  encrypter2.set_key (shared_secret.derivate_key (encrypter2.keylen << 3));
                }
              catch (GLib.Error e)
                {
                  assert_no_error (e);
                }

              timer.start ();

              try { yield stream1.splice_async (stream2, flags, GLib.Priority.LOW); average += timer.elapsed (); } catch (GLib.Error e)
                {
                  assert_no_error (e);
                }
            }

          GLib.Test.message ("average 1 MiB time: %04fs", average / (double) tt * (double) (1024 * 1024));
          GLib.Test.message ("transfer size: %s", GLib.format_size (tt, GLib.FormatSizeFlags.LONG_FORMAT));
        }
    }

  class TestStreamWrite : TestStreamSplice
    {

      public override async void test ()
        {
          var tt = (size_t) 0;
          var ns = (int) GLib.Test.rand_int_range ((int) ns_minsize, (int) ns_maxsize);

          var average = (double) 0;
          var timer = new GLib.Timer ();

          var input_stream = new GLib.MemoryInputStream ();
          var output_stream = new GLib.MemoryOutputStream.resizable ();
          var base_stream = new GLib.SimpleIOStream (input_stream, output_stream);
          var blocksz = (uint) 0;
          var test_stream = new GLib.MemoryOutputStream.resizable ();
          Krypt.IOStream stream;

          try
            {
              Krypt.Bc.DecryptConverter decrypter;
              Krypt.Bc.EncryptConverter encrypter;

              var private_secret = new Krypt.Dh.PrivateSecret.generate ();
              var public_secret = new Krypt.Dh.PublicSecret.generate (new Krypt.Dh.PrivateSecret.generate ());
              var shared_secret = new Krypt.Dh.SharedSecret (private_secret, public_secret);

              stream = new Krypt.IOStream (algo_name, mode_name, base_stream);
              stream.input_stream.get ("converter", out decrypter);
              stream.output_stream.get ("converter", out encrypter);
              decrypter.set_key (shared_secret.derivate_key (decrypter.keylen << 3));
              encrypter.set_key (shared_secret.derivate_key (encrypter.keylen << 3));
              blocksz = encrypter.blocksz;
            }
          catch (GLib.Error e)
            {
              assert_no_error (e);
              assert_not_reached ();
            }

          for (int i = 0; i < ns; ++i)
            {
              var vector = (Bytes) random_bytes_vector (1, blocksz * 3);
              var flags = (int) GLib.OutputStreamSpliceFlags.CLOSE_SOURCE;
              var io_priority = (int) GLib.Priority.HIGH;
              var input = new MemoryInputStream.from_bytes (vector);
              tt += vector.length;

              try { yield test_stream.splice_async (input, 0, io_priority); input.seek (0, GLib.SeekType.SET); } catch (GLib.Error e)
                {
                  assert_no_error (e);
                  assert_not_reached ();
                }

              timer.start ();

              try { yield stream.output_stream.splice_async (input, flags, io_priority); average += timer.elapsed (); } catch (GLib.Error e)
                {
                  assert_no_error (e);
                  assert_not_reached ();
                }
            }

          try
            {
              yield output_stream.close_async ();
              yield test_stream.close_async ();
              input_stream.add_bytes (output_stream.steal_as_bytes ());
            }
          catch (GLib.Error e)
            {
              assert_no_error (e);
              assert_not_reached ();
            }

          var bytes1 = test_stream.steal_as_bytes ();
          var flags = (int) GLib.OutputStreamSpliceFlags.CLOSE_TARGET;

          test_stream = new GLib.MemoryOutputStream.resizable ();

          try { yield test_stream.splice_async (stream.input_stream, flags); } catch (GLib.Error e)
            {
              assert_no_error (e);
              assert_not_reached ();
            }

          var bytes2 = test_stream.steal_as_bytes ();

          GLib.Test.message ("average 1 MiB time: %04fs", average / (double) tt * (double) (1024 * 1024));
          GLib.Test.message ("transfer size: %s", GLib.format_size (tt, GLib.FormatSizeFlags.LONG_FORMAT));
          assert_cmpmem (bytes1.get_data (), bytes2.get_data ());
        }
    }
}
