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
      return (int) hint;
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

          GLib.assert ((blocksz = algo.get_blocksz ()) <= uint8.MAX);
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
          if (finished)
            {
              read = written = 0;
              return GLib.ConverterResult.FINISHED;
            }
          else if (doreset)
            {
              cipher.reset ();
              doreset = false;
            }

          var blocksz = this.blocksz;
          var flush = (flags & (GLib.ConverterFlags.FLUSH | GLib.ConverterFlags.INPUT_AT_END)) != 0;
          var taking = alignfloor (inbuf.length, blocksz);
          var needed = taking == 0 ? 0 : taking - blocksz;
          var taken = (taking / blocksz) - (flush ? 0 : 1);

          if (needed > outbuf.length)

            throw new IOError.NO_SPACE ("bigger output buffer needed");
          else if (flush == false && (taken < 2))

            throw new IOError.PARTIAL_INPUT ("more input data needed");
          else
            {
              for (unowned size_t i = 0; i < taken; ++i)
                {
                  unowned var @in = (uint8[]) & inbuf [i * blocksz]; @in.length = (int) blocksz;
                  unowned var @out = (uint8[]) & outbuf [i * blocksz]; @out.length = (int) blocksz;

                  if ((taken - 1) == i && (GLib.ConverterFlags.INPUT_AT_END) != 0)

                    cipher.setfinal ();
                    cipher.decrypt (@out, @in);
                }

              read = (written = taken * blocksz);

              if (flush && written > 0)
                {
                  unowned var last = (uint8[]) & outbuf [0]; last.length = (int) written;
                  unowned var padd = parse_pkcs7 (last, blocksz);
                  written -= (size_t) padd;
                }

              return result_from_flags (flags);
            }
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
          if (finished)
            {
              read = written = 0;
              return GLib.ConverterResult.FINISHED;
            }
          else if (doreset)
            {
              cipher.reset ();
              doreset = false;
            }

          var blocksz = this.blocksz;
          var flush = (flags & (GLib.ConverterFlags.FLUSH | GLib.ConverterFlags.INPUT_AT_END)) != 0;
          var taking = alignfloor (inbuf.length, blocksz);
          var needed = flush == false ? taking : taking + blocksz;
          var taken = taking / blocksz;

          if (needed > outbuf.length)

            throw new IOError.NO_SPACE ("bigger output buffer needed");
          else if (flush == false && taken == 0)

            throw new IOError.PARTIAL_INPUT ("more input data needed");
          else
            {
              for (unowned size_t i = 0; i < taken; ++i)
                {
                  unowned var @in = (uint8[]) & inbuf [i * blocksz]; @in.length = (int) blocksz;
                  unowned var @out = (uint8[]) & outbuf [i * blocksz]; @out.length = (int) blocksz;
                  cipher.encrypt (@out, @in);
                }

              if (flush)
                {
                  GLib.assert (inbuf.length >= taking);
                  unowned var @in = (uint8[]) & inbuf [taken * blocksz]; @in.length = (int) blocksz;
                  unowned var @out = (uint8[]) & outbuf [taken * blocksz]; @out.length = (int) blocksz;

                  if (inbuf.length == taking)
                    {
                      GLib.Memory.set (& tmpblock [0], (int) blocksz, blocksz);
                      cipher.encrypt (@out, tmpblock);
                    }
                  else if (inbuf.length > taking)
                    {
                      unowned var s = (int) (inbuf.length - taking);
                      unowned var p = (int) (blocksz - s);
                      GLib.Memory.set (& tmpblock [s], p, p);
                      GLib.Memory.copy (& tmpblock [0], & @in [0], s);
                      cipher.encrypt (@out, tmpblock);
                    }
                }

              read = flush == false ? taking : inbuf.length;
              written = flush == false ? taking : taking + blocksz;
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
