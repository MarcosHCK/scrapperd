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

[CCode (cprefix = "DH", lower_case_cprefix = "dh_")]

namespace Dh
{
  [CCode (cheader_filename = "dhprotc.h")]

  public errordomain Error
    {
      FAILED;

      public static extern GLib.Quark quark ();

      public static void rethrow (owned GLib.Error error) throws Dh.Error requires (error.domain == ErrorCode.domain ())
        {
          error.domain = quark ();
          throw (Dh.Error) (owned) error;
        }
    }

  [Compact (opaque = true)] public class SharedSecret
    {
      internal Scalar x { get; private owned set; }

      public SharedSecret (PrivateSecret private_secret, PublicSecret public_secret)
        {
          this.x = new Scalar ();
          unowned var curve = private_secret.curve;
          unowned var d = private_secret.d;
          unowned var q = public_secret.q;
          var s = new Point ();

          curve.mul (s, d, q);
          curve.affine (x, null, s);
        }

      public static bool equals (SharedSecret a, SharedSecret b)
        {
          return Scalar.cmp (a.x, b.x) == 0;
        }

      public void derivate (uint8[] buffer, uint bitlen) throws Dh.Error

          requires (buffer.length >= ((bitlen + 7) >> 3))
        {
          try
            {
              unowned var buf = (uint8[]) & buffer [0];
              buf.length = (int) (bitlen + 7) >> 3;

              var ps = new uint8 [(x.nbits + 7) >> 3];
              x.to_buffer (Dh.ExternalFormat.USG, ps, null);
              Kdf.derive (ps, Dh.KdfAlgos.SCRYPT, 8, "some salt".data, 8, buf);
            }
          catch (GLib.Error e)
            {
              Error.rethrow ((owned) e);
              assert_not_reached ();
            }
        }

      public uint8[] derivate_key (uint bitlen) throws Dh.Error
        {
          uint8[] buffer;
          try { derivate (buffer = new uint8 [(bitlen + 7) >> 3], bitlen); } catch (GLib.Error e)
            {
              Error.rethrow ((owned) e);
              assert_not_reached ();
            }
          return (owned) buffer;
        }

      public GLib.Bytes derivate_key_as_bytes (uint bitlen) throws Dh.Error
        {
          try { return new Bytes.take (derivate_key (bitlen)); } catch (GLib.Error e)
            {
              Error.rethrow ((owned) e);
              assert_not_reached ();
            }
        }
    }

  [Compact (opaque = true)] public class PrivateSecret
    {
      internal Curve curve { get; private owned set; }
      internal Scalar d { get; private owned set; }

      private PrivateSecret (string? curve_name) throws Dh.Error
        {
          d = new Scalar ();

          try { curve = Curve.named (curve_name); } catch (GLib.Error e)
            {
              Error.rethrow ((owned) e);
              assert_not_reached ();
            }
        }

      public PrivateSecret.generate (string? curve_name = "Curve25519") throws Dh.Error
        {
          this (curve_name);

          Scalar n, p;
          GLib.assert ((n = curve.named_scalar ("n")) != null);

          try { p = Scalar.random_prime (1 + n.nbits, 0, null, null, RandomnessLevel.STRONG, 0); } catch (GLib.Error e)
            {
              Error.rethrow ((owned) e);
              assert_not_reached ();
            }

          Scalar.mod (d, p, n);
        }
    }

  [Compact (opaque = true)] public class PublicSecret
    {
      internal Point q { get; private owned set; }

      private PublicSecret ()
        {
          this.q = new Point ();
        }

      public PublicSecret.generate (PrivateSecret private_secret)
        {
          this ();
          unowned var curve = private_secret.curve;
          unowned var d = private_secret.d;
          Point g;

          GLib.assert ((g = curve.named_point ("g")) != null);
          curve.mul (q, d, g);
        }

      public PublicSecret.from_buffer (uint8[] buffer) throws Dh.Error
        {
          try { this.q = new Point.unpack (buffer); } catch (GLib.Error e)
            {
              Error.rethrow ((owned) e);
              assert_not_reached ();
            }
        }

      public static bool equals (PublicSecret a, PublicSecret b)
        {
          return Point.cmp (a.q, b.q) == 0;
        }

      public uint8[] get_data () throws Dh.Error
        {
          try { return q.pack (); } catch (GLib.Error e)
            {
              Error.rethrow ((owned) e);
              assert_not_reached ();
            }
        }

      public GLib.Bytes get_data_as_bytes () throws Dh.Error
        {
          return new Bytes.take (get_data ());
        }
    }

  public abstract class IOStream : GLib.IOStream
    {
      protected SharedSecret? shared_secret;
      public GLib.IOStream base_stream { get; construct; }

      public async override bool close_async (int io_priority, GLib.Cancellable? cancellable) throws GLib.IOError
        {
          return yield base_stream.close_async (io_priority, cancellable);
        }

      public async bool handshake_client (int io_priority, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var private_secret = new PrivateSecret.generate ();
          var public_secret = new PublicSecret.generate (private_secret);
          var input_stream = new DataInputStream (this.base_stream.input_stream);
          input_stream.close_base_stream = false;

          yield share_public_secret (public_secret, io_priority, cancellable);
          var foreign_secret = yield listen_public_secret (io_priority, cancellable);

          shared_secret = new SharedSecret (private_secret, foreign_secret);
          return true;
        }

      public async bool handshake_server (int io_priority, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var private_secret = new PrivateSecret.generate ();
          var public_secret = new PublicSecret.generate (private_secret);
          var input_stream = new DataInputStream (this.base_stream.input_stream);
          input_stream.close_base_stream = false;

          var foreign_secret = yield listen_public_secret (io_priority, cancellable);
          yield share_public_secret (public_secret, io_priority, cancellable);

          shared_secret = new SharedSecret (private_secret, foreign_secret);
          return true;
        }

      private async PublicSecret listen_public_secret (int io_priority, GLib.Cancellable? cancellable) throws GLib.Error
        {
          var line = yield next_line (io_priority, cancellable);
          var data = Base64.decode (line);
          var secret = new PublicSecret.from_buffer (data);
          return (owned) secret;
        }

      private async string next_line (int io_priority, GLib.Cancellable? cancellable) throws GLib.Error
        {
          var input_stream = new DataInputStream (this.base_stream.input_stream);
          input_stream.close_base_stream = false;

          size_t length = 0;
          string? line;

          if (unlikely ((line = yield input_stream.read_line_utf8_async (io_priority, cancellable, out length)) == null))

            throw new IOError.INVALID_DATA ("can not read next line");
          else
            return (owned) line;
        }

      private async bool share_public_secret (PublicSecret public_secret, int io_priority, GLib.Cancellable? cancellable) throws GLib.Error
        {
          var data = public_secret.get_data ();
          var line = Base64.encode (data);

          unowned var output_stream = (OutputStream) this.base_stream.output_stream;

          yield output_stream.write_all_async (line.data, io_priority, cancellable, null);
          yield output_stream.write_all_async ("\n".data, io_priority, cancellable, null);
          return true;
        }
    }
}
