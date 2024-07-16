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

[CCode (cprefix = "KryptBc", lower_case_cprefix = "krypt_bc_")]

namespace Krypt.Bc
{
  static size_t alignfloor (size_t value, size_t to)
    {
      return value - (value % to);
    }

  static int parse_pkcs7 (uint8[] block, size_t blocksz) requires (block.length > 0 && 0 == block.length % blocksz)
    {
      uint8 hint = block [block.length - 1];
      for (unowned uint8 i = 0; i < hint; ++i) if (block [block.length - 1 - i] != hint) return 0;
      return - (int) hint;
    }

  public abstract class BaseCipherConverter : GLib.Object, GLib.Initable
    {
      internal Cipher cipher;
      protected uint8[]? tmpblock;
      public string algo_name { get; construct; }
      private uint _blocksz;
      public uint blocksz { get { return _blocksz; } private set { tmpblock = new uint8 [_blocksz = value]; } }
      public uint keylen { get; private set; }
      public string mode_name { get; construct; }

      public bool init (GLib.Cancellable? cancellable) throws Krypt.Error
        {
          var algo = CipherAlgo.NONE;
          var flags = CipherFlags.ENABLE_SYNC;
          var mode = CipherMode.NONE;

          if ((algo = CipherAlgo.parse (algo_name)) == CipherAlgo.NONE)
            {
              throw new Error.FAILED ("unknown cipher algorithm %s", algo_name);
            }

          if ((mode = CipherMode.parse (mode_name)) == CipherMode.NONE)
            {
              throw new Error.FAILED ("unknown cipher mode %s", mode_name);
            }

          blocksz = algo.get_blocksz ();
          keylen = algo.get_keylen ();

          try { cipher = Cipher.open (algo, mode, flags); } catch (GLib.Error e)
            {
              Error.rethrow ((owned) e);
              assert_not_reached ();
            }

          return true;
        }

      public void set_key (uint8[] key) throws Krypt.Error
        {
          try { cipher.setkey (key); } catch (GLib.Error e)
            {
              Error.rethrow ((owned) e);
              assert_not_reached ();
            }
        }
    }

  public class DecryptConverter : BaseCipherConverter, GLib.Converter
    {
      bool doreset = false;
      bool finished = false;

      public DecryptConverter (string algo_name, string mode_name) throws GLib.Error
        {
          Object (algo_name : algo_name, mode_name : mode_name);
          init ();
        }

      public GLib.ConverterResult convert (uint8[] inbuf, uint8[] outbuf, GLib.ConverterFlags flags, out size_t read, out size_t written) throws GLib.Error
        {
          size_t _read = 0;
          size_t _written = 0;

          try
            {
              var result = convert6 (inbuf, outbuf, flags, out _read, out _written);
              read = _read;
              written = _written;
              printerr ("decrypt (.., %i, .., %i, %s, %i, %i, <none>);\n", (int) inbuf.length, (int) outbuf.length, flags.to_string (), (int) _read, (int) _written);
              return result;
            }
          catch (GLib.Error e)
            {
              var er = @"$(e.domain): $(e.code): $(e.message)";
              read = _read;
              written = _written;
              printerr ("decrypt (.., %i, .., %i, %s, %i, %i, %s);\n", (int) inbuf.length, (int) outbuf.length, flags.to_string (), (int) _read, (int) _written, er);
              throw (owned) e;
            }
        }

      public GLib.ConverterResult convert6 (uint8[] inbuf, uint8[] outbuf, GLib.ConverterFlags flags, out size_t read, out size_t written) throws GLib.Error
        {
          size_t blocksz = this.blocksz;
          size_t taken = (read = written = 0);
          size_t lost = 0;

          if (doreset)
            {
              cipher.reset ();
              doreset = false;
            }

          while (true)
            {
              var taken_in = alignfloor (inbuf.length, blocksz) / blocksz;
              var taken_out = alignfloor (outbuf.length, blocksz - 1) / (blocksz - 1);

              if (inbuf.length > 0 && (taken = size_t.min (taken_in, taken_out)) == 0)
                {
                  if (blocksz > outbuf.length)

                    throw new IOError.NO_SPACE ("bigger output buffer needed");
                  else if ((flags & GLib.ConverterFlags.INPUT_AT_END) == 0)

                    throw new IOError.PARTIAL_INPUT ("more input data needed");
                  else

                    throw new IOError.INVALID_DATA ("unaligned ciphered data (maybe lost data?)");
                }
              else if (inbuf.length > (lost = 0))
                {
                  for (int i = 0; i < taken; ++i)
                    {
                      unowned var @in = (uint8[]) & inbuf [i * (blocksz)]; @in.length = (int) blocksz;
                      unowned var @out = (uint8[]) & outbuf [i * (blocksz - 1)]; @out.length = (int) (blocksz - 1);
                      var pad = 0;

                      cipher.decrypt (tmpblock, @in);

                      lost -= (pad = parse_pkcs7 (tmpblock, blocksz));
                      GLib.Memory.copy (& @out [0], & tmpblock [0], blocksz + pad);
                    }

                  written = (read = blocksz * taken) - lost;
                }

              break;
            }

          return result_from_flags (flags);
        }

      public void reset () { doreset = true; finished = false; }

      private GLib.ConverterResult result_from_flags (GLib.ConverterFlags flags)
        {
          return (flags & (ConverterFlags.FLUSH | ConverterFlags.INPUT_AT_END)) == 0

            ? ConverterResult.CONVERTED
            : (finished = (flags & (ConverterFlags.INPUT_AT_END)) != 0) == false ? ConverterResult.FLUSHED : ConverterResult.FINISHED;
        }
    }

  public class EncryptConverter : BaseCipherConverter, GLib.Converter
    {
      bool doreset = false;
      bool finished = false;

      public EncryptConverter (string algo_name, string mode_name) throws GLib.Error
        {
          Object (algo_name : algo_name, mode_name : mode_name);
          init ();
        }

      public GLib.ConverterResult convert (uint8[] inbuf, uint8[] outbuf, GLib.ConverterFlags flags, out size_t read, out size_t written) throws GLib.Error
        {
          size_t _read = 0;
          size_t _written = 0;

          try
            {
              var result = convert8 (inbuf, outbuf, flags, out _read, out _written);
              read = _read;
              written = _written;
              printerr ("encrypt (.., %i, .., %i, %s, %i, %i, <none>);\n", (int) inbuf.length, (int) outbuf.length, flags.to_string (), (int) _read, (int) _written);
              return result;
            }
          catch (GLib.Error e)
            {
              var er = @"$(e.domain): $(e.code): $(e.message)";
              read = _read;
              written = _written;
              printerr ("encrypt (.., %i, .., %i, %s, %i, %i, %s);\n", (int) inbuf.length, (int) outbuf.length, flags.to_string (), (int) _read, (int) _written, er);
              throw (owned) e;
            }
        }

      public GLib.ConverterResult convert8 (uint8[] inbuf, uint8[] outbuf, GLib.ConverterFlags flags, out size_t read, out size_t written) throws GLib.Error
        {
          size_t blocksz = this.blocksz;
          size_t taken = (read = written = 0);

          if (doreset)
            {
              cipher.reset ();
              doreset = false;
            }

          while (true)
            {
              var taken_in = alignfloor (inbuf.length, blocksz - 1) / (blocksz - 1);
              var taken_out = alignfloor (outbuf.length, blocksz) / blocksz;

              if (inbuf.length > 0 && (taken = size_t.min (taken_in, taken_out)) == 0)
                {
                  if (blocksz > outbuf.length)

                    throw new IOError.NO_SPACE ("bigger output buffer needed");
                  else if ((flags & (ConverterFlags.FLUSH | ConverterFlags.INPUT_AT_END)) == 0)

                    throw new IOError.PARTIAL_INPUT ("more input data needed");
                  else
                    {
                      var padding = (int) (blocksz - inbuf.length % blocksz);

                      GLib.Memory.copy (& tmpblock [0], & inbuf [0], inbuf.length);

                      for (unowned var i = inbuf.length; i < tmpblock.length; ++i)

                        tmpblock [i] = (uint8) padding;

                        read = inbuf.length;
                        written = tmpblock.length;

                      if ((flags & ConverterFlags.INPUT_AT_END) != 0)

                        cipher.setfinal ();
                        cipher.encrypt (outbuf, tmpblock);

                      if ((flags & ConverterFlags.FLUSH) != 0)

                        cipher.reset ();
                    }
                }
              else if (inbuf.length > 0)
                {
                  for (int i = 0; i < taken; ++i)
                    {
                      unowned var @in = (uint8[]) & inbuf [i * (blocksz - 1)]; @in.length = (int) (blocksz - 1);
                      unowned var @out = (uint8[]) & outbuf [i * (blocksz)]; @out.length = (int) blocksz;

                      GLib.Memory.copy (& tmpblock [0], & @in [0], @in.length);
                      tmpblock [blocksz - 1] = 1;

                      cipher.encrypt (@out, tmpblock);
                    }

                  read = (written = blocksz * taken) - taken;
                }

              break;
            }

          return result_from_flags (flags);
        }

      public void reset () { doreset = true; finished = false; }

      private GLib.ConverterResult result_from_flags (GLib.ConverterFlags flags)
        {
          return (flags & (ConverterFlags.FLUSH | ConverterFlags.INPUT_AT_END)) == 0

            ? ConverterResult.CONVERTED
            : (finished = (flags & (ConverterFlags.INPUT_AT_END)) != 0) == false ? ConverterResult.FLUSHED : ConverterResult.FINISHED;
        }
    }
}
