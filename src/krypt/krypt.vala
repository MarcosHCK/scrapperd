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

[CCode (cprefix = "Krypt", lower_case_cprefix = "krypt_")]

namespace Krypt
{
  class MyConverterInputStream : GLib.FilterInputStream
    {
      public Bc.DecryptConverter converter { get; construct; }

      private uint8[] block;
      private uint available;
      private uint blocksz;
      private uint copied;
      private uint8[] interned;

      construct
        {
          blocksz = (uint) converter.blocksz;

          available = copied = 0;
          block = new uint8 [blocksz];
          interned = new uint8 [2 * blocksz];

          bind_property ("close_base_stream", base_stream, "close_base_stream", GLib.BindingFlags.SYNC_CREATE);
        }

      public MyConverterInputStream (GLib.InputStream base_stream, Bc.DecryptConverter converter)
        {
          Object (base_stream : new GLib.BufferedInputStream (base_stream), converter : converter);
        }

      public override bool close (GLib.Cancellable? cancellable) throws GLib.IOError
        {
          return base_stream.close (cancellable);
        }

      public override ssize_t read (uint8[] buffer, GLib.Cancellable? cancellable = null) throws GLib.IOError
        {
          while (true)

            if (copied < available)
              {
                var to = uint.min (buffer.length, available - copied);
                GLib.Memory.copy (& buffer [0], & interned [copied], to);
                copied += to;
                return to;
              }
            else
              {
                copied = 0;
                unowned size_t read_ = 0, wrote = 0;
                unowned var flags = (ConverterFlags) GLib.ConverterFlags.FLUSH;

                try { read_ = ((GLib.BufferedInputStream) base_stream).fill (block.length, cancellable); } catch (GLib.Error e)
                  {
                    throw (GLib.IOError) (owned) e;
                  }

                if (read_ > 0) read_ = 0; else return 0;

                ((GLib.BufferedInputStream) base_stream).read (block, cancellable);

                try { converter.convert (block, interned, flags, out read_, out wrote); } catch (GLib.Error e)
                  {
                    if (e.domain == GLib.IOError.quark ())

                      throw (GLib.IOError) (owned) e;
                    else
                      throw new GLib.IOError.FAILED ("can not decrypt block: %s", e.message);
                  }

                GLib.assert (read_ == block.length);
                available = (uint) wrote;
              }
        }
    }

  class MyConverterOutputStream : GLib.FilterOutputStream
    {
      public Bc.EncryptConverter converter { get; construct; }
      public size_t blocksz { get; construct; }
      private uint8[] interned;

      construct
        {
          blocksz = converter.blocksz;
          interned = new uint8 [2 * blocksz];
        }

      public MyConverterOutputStream (GLib.OutputStream base_stream, Bc.EncryptConverter converter)
        {
          Object (base_stream : base_stream, converter : converter);
        }

      public override bool close (GLib.Cancellable? cancellable) throws GLib.IOError
        {
          if (close_base_stream) return base_stream.close (cancellable);
          return true;
        }

      public unowned uint8[] convert (uint8[] buffer, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          size_t read_ = 0, wrote = 0;
          unowned var @out = (uint8[]) & interned [0];
          unowned var flags = (ConverterFlags) GLib.ConverterFlags.FLUSH;

          try { converter.convert (@buffer, interned, flags, out read_, out wrote); } catch (GLib.Error e)
            {
              if (e.domain == GLib.IOError.quark ())

                throw (GLib.IOError) (owned) e;
              else
                throw new GLib.IOError.FAILED ("can not decrypt block: %s", e.message);
            }

          GLib.assert (read_ == buffer.length);
          @out.length = (int) wrote;
          return @out;
        }

      public override ssize_t write (uint8[] buffer, GLib.Cancellable? cancellable = null) throws GLib.IOError
        {
          var blocksz = (size_t) (this.blocksz - 1);
          var last = (size_t) (buffer.length % blocksz);
          var blocks = (size_t) (((size_t) buffer.length - last) / blocksz);

          for (unowned size_t i = 0; i < blocks; ++i)
            {
              unowned var @in = (uint8[]) & buffer [i * blocksz]; @in.length = (int) blocksz;
              unowned var @out = (uint8[]) null;

              try { @out = convert (@in, cancellable); } catch (GLib.Error e) { throw (IOError) (owned) e; }
              base_stream.write_all (@out, null, cancellable);
            }

          if (last > 0)
            {
              unowned var @in = (uint8[]) & buffer [buffer.length - last]; @in.length = (int) last;
              unowned var @out = (uint8[]) null;

              try { @out = convert (@in, cancellable); } catch (GLib.Error e) { throw (IOError) (owned) e; }
              base_stream.write_all (@out, null, cancellable);
            }

          return buffer.length;
        }
    }

  public class IOStream : Krypt.Dh.IOStream, GLib.Initable
    {
      private MyConverterInputStream _input_stream;
      private MyConverterOutputStream _output_stream;
      private uint keylen;

      public string algo_name { get; construct; }
      public string mode_name { get; construct; }

      public override GLib.InputStream input_stream { get { return _input_stream; } }
      public override GLib.OutputStream output_stream { get { return _output_stream; } }

      public IOStream (string algo_name, string mode_name, GLib.IOStream base_stream) throws GLib.Error
        {
          Object (algo_name : algo_name, base_stream : base_stream, mode_name : mode_name);
          init ();
        }

      public override bool handshake_done (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var bitlen = keylen << 3;
          var key = (uint8[]) shared_secret.derivate_key (bitlen);
          ((Bc.DecryptConverter) _input_stream.converter).set_key (key);
          ((Bc.EncryptConverter) _output_stream.converter).set_key (key);
          return true;
        }

      public bool init (GLib.Cancellable? cancellable) throws GLib.Error
        {
          var input_converter = new Bc.DecryptConverter (algo_name, mode_name);
          var output_converter = new Bc.EncryptConverter (algo_name, mode_name);
          keylen = input_converter.keylen;

          _input_stream = new MyConverterInputStream (base_stream.input_stream, input_converter);
          _output_stream = new MyConverterOutputStream (base_stream.output_stream, output_converter);
          return true;
        }
    }
}
