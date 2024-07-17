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
  public class IOStream : Krypt.Dh.IOStream, GLib.Initable
    {
      private GLib.InputStream _input_stream;
      private GLib.OutputStream _output_stream;

      public string algo_name { get; construct; }
      public string mode_name { get; construct; }

      public bool close_base_stream { get; construct; default = true; }
      public override GLib.InputStream input_stream { get { return _input_stream; } }
      public override GLib.OutputStream output_stream { get { return _output_stream; } }

      public IOStream (string algo_name, string mode_name, GLib.IOStream base_stream) throws GLib.Error
        {
          Object (algo_name : algo_name, base_stream : base_stream, mode_name : mode_name);
          init ();
        }

      public override async bool handshake_client (int io_priority, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          yield base.handshake_client (io_priority, cancellable);
          var keylen = ((Bc.DecryptConverter) ((GLib.ConverterInputStream) _input_stream).converter).keylen;
          var key = shared_secret.derivate_key (keylen << 3);
          ((Bc.DecryptConverter) ((GLib.ConverterInputStream) _input_stream).converter).set_key (key);
          ((Bc.EncryptConverter) ((GLib.ConverterOutputStream) _output_stream).converter).set_key (key);
          return true;
        }

      public override async bool handshake_server (int io_priority, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          yield base.handshake_server (io_priority, cancellable);
          var keylen = ((Bc.DecryptConverter) ((GLib.ConverterInputStream) _input_stream).converter).keylen;
          var key = shared_secret.derivate_key (keylen << 3);
          ((Bc.DecryptConverter) ((GLib.ConverterInputStream) _input_stream).converter).set_key (key);
          ((Bc.EncryptConverter) ((GLib.ConverterOutputStream) _output_stream).converter).set_key (key);
          return true;
        }

      public bool init (GLib.Cancellable? cancellable) throws GLib.Error
        {
          var input_converter = new Bc.DecryptConverter (algo_name, mode_name);
          var output_converter = new Bc.EncryptConverter (algo_name, mode_name);
          _input_stream = new GLib.ConverterInputStream (base_stream.input_stream, input_converter);
          _output_stream = new GLib.ConverterOutputStream (base_stream.output_stream, output_converter);
          output_converter.blocking = false;
          return true;
        }
    }
}
