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

[CCode (cprefix = "KryptDh", lower_case_cprefix = "krypt_dh_")]

namespace Krypt.Dh
{
  [Compact (opaque = true)] public class SharedSecret
    {
      internal Scalar x { get; private owned set; }

      public SharedSecret (PrivateSecret private_secret, PublicSecret public_secret)
        {
          Krypt._gcry_init ();
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

      public void derivate (uint8[] buffer, uint bitlen) throws Krypt.Error

          requires (buffer.length >= ((bitlen + 7) >> 3))
        {
          try
            {
              unowned var buf = (uint8[]) & buffer [0];
              buf.length = (int) (bitlen + 7) >> 3;

              var ps = new uint8 [(x.nbits + 7) >> 3];
              x.to_buffer (ExternalFormat.USG, ps, null);
              Kdf.derive (ps, KdfAlgos.SCRYPT, 8, "some salt".data, 8, buf);
            }
          catch (GLib.Error e)
            {
              Error.rethrow ((owned) e);
              assert_not_reached ();
            }
        }

      public uint8[] derivate_key (uint bitlen) throws Krypt.Error
        {
          uint8[] buffer;
          derivate (buffer = new uint8 [(bitlen + 7) >> 3], bitlen);
          return (owned) buffer;
        }

      public GLib.Bytes derivate_key_as_bytes (uint bitlen) throws Krypt.Error
        {
          return new Bytes.take (derivate_key (bitlen));
        }
    }

  [Compact (opaque = true)] public class PrivateSecret
    {
      internal Curve curve { get; private owned set; }
      internal Scalar d { get; private owned set; }

      private PrivateSecret (string curve_name) throws Krypt.Error
        {
          Krypt._gcry_init ();

          d = new Scalar ();

          try { curve = Curve.named (curve_name); } catch (GLib.Error e)
            {
              Error.rethrow ((owned) e);
              assert_not_reached ();
            }
        }

      public PrivateSecret.generate (string curve_name = "Curve25519") throws Krypt.Error
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
          Krypt._gcry_init ();

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

      public PublicSecret.from_buffer (uint8[] buffer) throws Krypt.Error
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

      public uint8[] get_data () throws Krypt.Error
        {
          try { return q.pack (); } catch (GLib.Error e)
            {
              Error.rethrow ((owned) e);
              assert_not_reached ();
            }
        }

      public GLib.Bytes get_data_as_bytes () throws Krypt.Error
        {
          return new Bytes.take (get_data ());
        }
    }

  public abstract class IOStream : GLib.IOStream
    {
      public GLib.IOStream base_stream { get; construct; }
      public bool close_base_stream { get; construct; default = true; }
      public string curve_name { get; construct; }
      protected SharedSecret? shared_secret = null;

      construct
        {
          if (curve_name == null) curve_name = "Curve25519";
        }

      class construct
        {
          Krypt._gcry_init ();
        }

      public override bool close (GLib.Cancellable? cancellable = null) throws GLib.IOError
        {
          if (close_base_stream) return base_stream.close (cancellable);
          return true;
        }

      public async bool handshake_client (int io_priority, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          Scalar? p;
          var private_secret = new PrivateSecret.generate (curve_name);
          var public_secret = new PublicSecret.generate (private_secret);
          GLib.assert ((p = private_secret.curve.named_scalar ("p")) != null);

          yield share_public_secret (public_secret, io_priority, cancellable);
          var foreign_secret = yield listen_public_secret (p.nbits, io_priority, cancellable);

          shared_secret = new SharedSecret (private_secret, foreign_secret);
          return handshake_done (cancellable);
        }

      public virtual bool handshake_done (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          return true;
        }

      public async bool handshake_server (int io_priority, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          Scalar? p;
          var private_secret = new PrivateSecret.generate (curve_name);
          var public_secret = new PublicSecret.generate (private_secret);
          GLib.assert ((p = private_secret.curve.named_scalar ("p")) != null);

          var foreign_secret = yield listen_public_secret (p.nbits, io_priority, cancellable);
          yield share_public_secret (public_secret, io_priority, cancellable);

          shared_secret = new SharedSecret (private_secret, foreign_secret);
          return handshake_done (cancellable);
        }

      private async PublicSecret listen_public_secret (uint pbits, int io_priority, GLib.Cancellable? cancellable) throws GLib.Error
        {
          var line = yield next_line (pbits, io_priority, cancellable);
          var data = Base64.decode (line);
          var secret = new PublicSecret.from_buffer (data);
          return (owned) secret;
        }

      private async string next_line (uint pbits, int io_priority, GLib.Cancellable? cancellable) throws GLib.Error
        {
          var expected_decodedsz = ((pbits + 7) / 8) * 3 + Packed.OVERHEAD;
          var expected_encodedsz = (expected_decodedsz / 3 + 1) * 4;
          var expected_sz = expected_encodedsz * 2;
          var builder = new StringBuilder.sized (expected_sz);
          uint8 byte [1];

          unowned var input_stream = (GLib.InputStream) this.base_stream.input_stream;

          while (true)
            {
              if (0 == yield input_stream.read_async (byte, io_priority, cancellable))

                throw new IOError.FAILED ("unexpected end of stream");

              if (byte [0] == '\n') break; else

                builder.append_c ((char) byte [0]);

              if (builder.len > expected_sz)

                throw new IOError.INVALID_DATA ("foreign public key too long");
            }

          return builder.free_and_steal ();
        }

      private async bool share_public_secret (PublicSecret public_secret, int io_priority, GLib.Cancellable? cancellable) throws GLib.Error
        {
          var data = public_secret.get_data ();
          var line = Base64.encode (data);

          unowned var output_stream = (GLib.OutputStream) this.base_stream.output_stream;

          yield output_stream.write_all_async (line.data, io_priority, cancellable, null);
          yield output_stream.write_all_async ("\n".data, io_priority, cancellable, null);
          return true;
        }
    }
}
