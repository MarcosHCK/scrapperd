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
using Krypt.Bc;

namespace Testing
{
  public static int main (string[] args)
    {
      GLib.Test.init (ref args, null);
      GLib.Test.add_func (TESTPATHROOT + "/Krypto/BC/new", () => (new TestNew ()).run ());
      GLib.Test.add_func (TESTPATHROOT + "/Krypto/BC/step", () => (new TestStep ()).run ());
      return GLib.Test.run ();
    }

  class TestNew : SyncTest
    {
      protected override void test ()
        {
          var ni = GLib.Random.int_range (100, 1000);

          var average = (double) 0;
          var timer = new GLib.Timer ();

          for (unowned var i = 0; i < ni; ++i)
            {
              EncryptConverter converter;
              timer.start ();

              try { converter = new EncryptConverter ("AES", "CBC"); average += timer.elapsed (); } catch (GLib.Error e)
                {
                  assert_no_error (e);
                  break;
                }

              var key = new uint8 [converter.keylen];

              for (unowned var j = 0; j < key.length; ++j)
                {
                  key [j] = (uint8) GLib.Random.int_range (0, uint8.MAX);
                }

              try { converter.set_key (key); } catch (GLib.Error e)
                {
                  assert_no_error (e);
                  break;
                }
            }

          GLib.Test.message ("average create time: %04fs", average / (double) ni);
          GLib.Test.message ("ciphers created: %i", ni);
        }
    }

  class TestStep : AsyncTest
    {
      protected override async void test ()
        {
          var ni = GLib.Random.int_range (100, 1000);

          var average = (double) 0;
          var timer = new GLib.Timer ();

          var unaligned = 0;

          for (unowned var i = 0; i < ni; ++i)
            {
              DecryptConverter d_converter;
              EncryptConverter e_converter;

              try { d_converter = new DecryptConverter ("AES", "CBC"); } catch (GLib.Error e)
                {
                  assert_no_error (e);
                  break;
                }

              try { e_converter = new EncryptConverter ("AES", "CBC"); } catch (GLib.Error e)
                {
                  assert_no_error (e);
                  break;
                }

              var alpha = GLib.Random.int_range (0, (int32) (1 + d_converter.blocksz * 2));
              var delta = GLib.Random.int_range (100, 1000);

              if ((alpha = alpha > d_converter.blocksz ? 0 : alpha) > 0) ++unaligned;

              var data = new uint8 [d_converter.blocksz * delta + alpha];
              var key = new uint8 [d_converter.keylen];

              for (unowned var j = 0; j < data.length; ++j) data [j] = (uint8) GLib.Random.int_range (0, uint8.MAX);
              for (unowned var j = 0; j < key.length; ++j) key [j] = (uint8) GLib.Random.int_range (0, uint8.MAX);

              try { d_converter.set_key (key); e_converter.set_key (key); } catch (GLib.Error e)
                {
                  assert_no_error (e);
                  break;
                }

              var vector = new Bytes.take ((owned) data);
              var istream = new MemoryInputStream.from_bytes (vector);
              var ostream = new MemoryOutputStream.resizable ();

              var flags1 = GLib.OutputStreamSpliceFlags.CLOSE_SOURCE;
              var flags2 = GLib.OutputStreamSpliceFlags.CLOSE_TARGET;
              var flags = flags1 | flags2;
              var filter1 = new ConverterOutputStream (ostream, d_converter);
              var filter2 = new ConverterInputStream (istream, e_converter);

              timer.start ();

              try { yield filter1.splice_async (filter2, flags, Priority.DEFAULT); average += timer.elapsed (); } catch (GLib.Error e)
                {
                  assert_no_error (e);
                  break;
                }

              var got = ostream.steal_as_bytes ();

              assert_cmpmem (got.get_data (), vector.get_data ());
            }

          GLib.Test.message ("average step time: %04fs", average / (double) ni);
          GLib.Test.message ("steps done: %i", ni);
          GLib.Test.message ("unaligned steps: %i", unaligned);
        }
    }
}
