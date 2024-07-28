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
      return GLib.Test.run ();
    }

  class TestStreamSplice : AsyncTest
    {
      const string algo_name = "AES";
      const string mode_name = "CBC";

      static GLib.Bytes random_bytes_vector (uint minsize, uint maxsize)
        {
          var size = GLib.Random.int_range ((int32) minsize, (int32) maxsize);
          var data = new uint8 [size];

          for (int i = 0; i < size; ++i) data [i] = (uint8) GLib.Random.int_range (0, uint8.MAX);
          return new GLib.Bytes.take ((owned) data);
        }

      protected override async void test ()
        {
          Krypt.IOStream stream1, stream2;
          var vector1 = random_bytes_vector (1000, 10000);
          var vector2 = random_bytes_vector (1000, 10000);

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

          try { yield stream1.splice_async (stream2, flags, GLib.Priority.LOW); } catch (GLib.Error e)
            {
              assert_no_error (e);
            }
        }
    }
}
