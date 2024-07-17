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
  [CCode (cname = "_gcry_init")]
  internal static void _gcry_init ();

  [CCode (cheader_filename = "gcryptapi.h", cname = "gcry_randomize")]

  internal void randomize ([CCode (array_length_pos = 1.1, array_length_type = "size_t", type = "void*")] uint8[] buffer, RandomnessLevel level);

  [CCode (cheader_filename = "gcryptapi.h", cname = "struct gcry_cipher_handle", free_function = "gcry_cipher_close")] [Compact (opaque = true)]

  internal class Cipher
    {
      [CCode (cname = "gcry_cipher_decrypt")]
      private ErrorCode _decrypt ([CCode (array_length_pos = 1.1, array_length_type = "size_t")] uint8[] @out, [CCode (array_length_pos = 2.1, array_length_type = "size_t")] uint8[] @in);
      [CCode (cname = "gcry_cipher_encrypt")]
      private ErrorCode _encrypt ([CCode (array_length_pos = 1.1, array_length_type = "size_t")] uint8[] @out, [CCode (array_length_pos = 2.1, array_length_type = "size_t")] uint8[] @in);
      [CCode (cname = "gcry_cipher_open")]
      private static ErrorCode _open (out Cipher cipher, [CCode (type = "int")] CipherAlgo algo, [CCode (type = "int")] CipherMode mode, [CCode (type = "int")] CipherFlags flags);
      [CCode (cname = "gcry_cipher_setkey")]
      private ErrorCode _setkey ([CCode (array_length_pos = 1.1, array_length_type = "size_t")] uint8[] key);
      [CCode (cname = "gcry_cipher_reset")]
      public ErrorCode _reset ();
      [CCode (cname = "gcry_cipher_final")]
      public ErrorCode _setfinal ();

      public bool decrypt (uint8[] @out, uint8[] @in) throws GLib.Error
        {
          ErrorCode code;

          if (GLib.unlikely ((code = _decrypt (@out, @in)) != 0))

            throw new GLib.Error.literal (ErrorCode.domain (), (int) code, code.to_string ());
          return true;
        }

      public bool encrypt (uint8[] @out, uint8[] @in) throws GLib.Error
        {
          ErrorCode code;

          if (GLib.unlikely ((code = _encrypt (@out, @in)) != 0))

            throw new GLib.Error.literal (ErrorCode.domain (), (int) code, code.to_string ());
          return true;
        }

      public static Cipher open ([CCode (type = "int")] CipherAlgo algo, [CCode (type = "int")] CipherMode mode, [CCode (type = "int")] CipherFlags flags) throws GLib.Error
        {
          Cipher cipher;
          ErrorCode code;

          if (GLib.unlikely ((code = _open (out cipher, algo, mode, flags)) != 0))

            throw new GLib.Error.literal (ErrorCode.domain (), (int) code, code.to_string ());
          return (owned) cipher;
        }

      public bool reset () throws GLib.Error
        {
          ErrorCode code;

          if (GLib.unlikely ((code = _reset ()) != 0))

            throw new GLib.Error.literal (ErrorCode.domain (), (int) code, code.to_string ());
          return true;
        }

      public bool setfinal () throws GLib.Error
        {
          ErrorCode code;

          if (GLib.unlikely ((code = _setfinal ()) != 0))

            throw new GLib.Error.literal (ErrorCode.domain (), (int) code, code.to_string ());
          return true;
        }

      public bool setkey (uint8[] key) throws GLib.Error
        {
          ErrorCode code;

          if (GLib.unlikely ((code = _setkey (key)) != 0))

            throw new GLib.Error.literal (ErrorCode.domain (), (int) code, code.to_string ());
          return true;
        }
    }

  [CCode (cheader_filename = "gcryptapi.h", cname = "enum gcry_cipher_algos")]

  internal enum CipherAlgo
    {
      [CCode (cname = "GCRY_CIPHER_NONE")] NONE,
      [CCode (cname = "GCRY_CIPHER_IDEA")] IDEA,
      [CCode (cname = "GCRY_CIPHER_3DES")] THREEDES,
      [CCode (cname = "GCRY_CIPHER_CAST5")] CAST5,
      [CCode (cname = "GCRY_CIPHER_BLOWFISH")] BLOWFISH,
      [CCode (cname = "GCRY_CIPHER_SAFER_SK128")] SAFER_SK128,
      [CCode (cname = "GCRY_CIPHER_DES_SK")] DES_SK,
      [CCode (cname = "GCRY_CIPHER_AES")] AES,
      [CCode (cname = "GCRY_CIPHER_AES192")] AES192,
      [CCode (cname = "GCRY_CIPHER_AES256")] AES256,
      [CCode (cname = "GCRY_CIPHER_TWOFISH")] TWOFISH,
      [CCode (cname = "GCRY_CIPHER_ARCFOUR")] ARCFOUR,
      [CCode (cname = "GCRY_CIPHER_DES")] DES,
      [CCode (cname = "GCRY_CIPHER_TWOFISH128")] TWOFISH128,
      [CCode (cname = "GCRY_CIPHER_SERPENT128")] SERPENT128,
      [CCode (cname = "GCRY_CIPHER_SERPENT192")] SERPENT192,
      [CCode (cname = "GCRY_CIPHER_SERPENT256")] SERPENT256,
      [CCode (cname = "GCRY_CIPHER_RFC2268_40")] RFC2268_40,
      [CCode (cname = "GCRY_CIPHER_RFC2268_128")] RFC2268_128,
      [CCode (cname = "GCRY_CIPHER_SEED")] SEED,
      [CCode (cname = "GCRY_CIPHER_CAMELLIA128")] CAMELLIA128,
      [CCode (cname = "GCRY_CIPHER_CAMELLIA192")] CAMELLIA192,
      [CCode (cname = "GCRY_CIPHER_CAMELLIA256")] CAMELLIA256,
      [CCode (cname = "GCRY_CIPHER_SALSA20")] SALSA20,
      [CCode (cname = "GCRY_CIPHER_SALSA20R12")] SALSA20R12,
      [CCode (cname = "GCRY_CIPHER_GOST28147")] GOST28147,
      [CCode (cname = "GCRY_CIPHER_CHACHA20")] CHACHA20,
      [CCode (cname = "GCRY_CIPHER_GOST28147_MESH")] GOST28147_MESH,
      [CCode (cname = "GCRY_CIPHER_SM4")] SM4;

      [CCode (cname = "gcry_cipher_get_algo_blklen")]
      public uint get_blocksz ();
      [CCode (cname = "gcry_cipher_get_algo_keylen")]
      public uint get_keylen ();

      [CCode (cname = "gcry_cipher_map_name")]
      public static CipherAlgo parse (string name);
      [CCode (cname = "gcry_cipher_algo_name")]
      public unowned string to_string ();
    }

  [CCode (cheader_filename = "gcryptapi.h", cname = "enum gcry_cipher_flags")]
  [Flags]

  internal enum CipherFlags
    {
      [CCode (cname = "GCRY_CIPHER_SECURE")] SECURE,
      [CCode (cname = "GCRY_CIPHER_ENABLE_SYNC")] ENABLE_SYNC,
      [CCode (cname = "GCRY_CIPHER_CBC_CTS")] CBC_CTS,
      [CCode (cname = "GCRY_CIPHER_CBC_MAC")] CBC_MAC,
      [CCode (cname = "GCRY_CIPHER_EXTENDED")] EXTENDED,
    }

  [CCode (cheader_filename = "gcryptapi.h", cname = "enum gcry_cipher_modes")]

  internal enum CipherMode
    {
      [CCode (cname = "GCRY_CIPHER_MODE_NONE")] NONE,
      [CCode (cname = "GCRY_CIPHER_MODE_ECB")] ECB,
      [CCode (cname = "GCRY_CIPHER_MODE_CFB")] CFB,
      [CCode (cname = "GCRY_CIPHER_MODE_CBC")] CBC,
      [CCode (cname = "GCRY_CIPHER_MODE_STREAM")] STREAM,
      [CCode (cname = "GCRY_CIPHER_MODE_OFB")] OFB,
      [CCode (cname = "GCRY_CIPHER_MODE_CTR")] CTR,
      [CCode (cname = "GCRY_CIPHER_MODE_AESWRAP")] AESWRAP,
      [CCode (cname = "GCRY_CIPHER_MODE_CCM")] CCM,
      [CCode (cname = "GCRY_CIPHER_MODE_GCM")] GCM,
      [CCode (cname = "GCRY_CIPHER_MODE_POLY1305")] POLY1305,
      [CCode (cname = "GCRY_CIPHER_MODE_OCB")] OCB,
      [CCode (cname = "GCRY_CIPHER_MODE_CFB8")] CFB8,
      [CCode (cname = "GCRY_CIPHER_MODE_XTS")] XTS,
      [CCode (cname = "GCRY_CIPHER_MODE_EAX")] EAX,
      [CCode (cname = "GCRY_CIPHER_MODE_SIV")] SIV,
      [CCode (cname = "GCRY_CIPHER_MODE_GCM_SIV")] GCM_SIV;

      public static CipherMode parse (string mode_name)
        {
          switch (mode_name)
            {
              case "ECB": return CipherMode.ECB;
              case "CFB": return CipherMode.CFB;
              case "CBC": return CipherMode.CBC;
              case "STREAM": return CipherMode.STREAM;
              case "OFB": return CipherMode.OFB;
              case "CTR": return CipherMode.CTR;
              case "AESWRAP": return CipherMode.AESWRAP;
              case "CCM": return CipherMode.CCM;
              case "GCM": return CipherMode.GCM;
              case "POLY1305": return CipherMode.POLY1305;
              case "OCB": return CipherMode.OCB;
              case "CFB8": return CipherMode.CFB8;
              case "XTS": return CipherMode.XTS;
              case "EAX": return CipherMode.EAX;
              case "SIV": return CipherMode.SIV;
              case "GCM_SIV": return CipherMode.GCM_SIV;
            }

          return CipherMode.NONE;
        }
    }

  [CCode (cheader_filename = "gcryptapi.h", cname = "struct gcry_context", free_function = "gcry_ctx_release")] [Compact (opaque = true)]

  internal class Curve
    {
      [CCode (cname = "gcry_mpi_ec_get_affine", instance_pos = 3.1)]
      public void affine (Scalar? x, Scalar? y, Point p);
      [CCode (cname = "gcry_mpi_ec_mul", instance_pos = 3.1)]
      public void mul (Point result, Scalar factor, Point point);
      [CCode (cname = "gcry_mpi_ec_get_point", instance_pos = 1.1)]
      public Point? named_point (string name, [CCode (type = "int")] bool noconst = false);
      [CCode (cname = "gcry_mpi_ec_get_mpi", instance_pos = 1.1)]
      public Scalar? named_scalar (string name, [CCode (type = "int")] bool noconst = false);
      [CCode (cname = "gcry_mpi_ec_new")]
      public static ErrorCode @new (out Curve curve, void* sexp, string? curve_name);

      public static Curve named (string curve_name) throws GLib.Error
        {
          _gcry_init ();
          Curve curve;
          ErrorCode code = @new (out curve, null, curve_name);

          if (GLib.unlikely (code != 0))

            throw new GLib.Error.literal (ErrorCode.domain (), (int) code, code.to_string ());
          return curve;
        }
    }

  [CCode (cheader_filename = "gcryptapi.h", cname = "gcry_error_t")] [SimpleType] [IntegerType (rank = 7)]

  internal struct ErrorCode : uint
    {
      [CCode (cname = "_gcry_error_quark")]
      public static GLib.Quark domain ();
      [CCode (cname = "_gcry_strerror")]
      public unowned string to_string ();
    }

  [CCode (cheader_filename = "gcryptapi.h", cname = "enum gcry_mpi_format")]

  public enum ExternalFormat
    {
      [CCode (cname = "GCRYMPI_FMT_NONE")] NONE,
      [CCode (cname = "GCRYMPI_FMT_STD")] STD,
      [CCode (cname = "GCRYMPI_FMT_PGP")] PGP,
      [CCode (cname = "GCRYMPI_FMT_SSH")] SSH,
      [CCode (cname = "GCRYMPI_FMT_HEX")] HEX,
      [CCode (cname = "GCRYMPI_FMT_USG")] USG,
    }

  [CCode (cheader_filename = "gcryptapi.h")]

  namespace Kdf
    {
      [CCode (cheader_filename = "gcrypt.h", cname = "gcry_kdf_derive")]

      private ErrorCode _derive ([CCode (array_length_pos = 1.1, array_length_type = "size_t")] uint8[] passphrase, KdfAlgos algo, int subalgo, [CCode (array_length_pos = 4.1, array_length_type = "size_t")] uint8[] salt, ulong iterations, [CCode (array_length_pos = 5.9, array_length_type = "size_t")] uint8[] key);

      internal void derive (uint8[] passphrase, KdfAlgos algo, int subalgo, uint8[] salt, ulong iterations, uint8[] key) throws GLib.Error
        {
          ErrorCode code;

          if (GLib.unlikely ((code = _derive (passphrase, algo, subalgo, salt, iterations, key)) != 0))

            throw new GLib.Error.literal (ErrorCode.domain (), (int) code, code.to_string ());
        }
    }

  [CCode (cheader_filename = "gcryptapi.h", cname = "enum gcry_kdf_algos")]

  internal enum KdfAlgos
    {
      [CCode (cname = "GCRY_KDF_NONE")] NONE,
      [CCode (cname = "GCRY_KDF_SIMPLE_S2K")] SIMPLE_S2K,
      [CCode (cname = "GCRY_KDF_SALTED_S2K")] SALTED_S2K,
      [CCode (cname = "GCRY_KDF_ITERSALTED_S2K")] ITERSALTED_S2K,
      [CCode (cname = "GCRY_KDF_PBKDF1")] PBKDF1,
      [CCode (cname = "GCRY_KDF_PBKDF2")] PBKDF2,
      [CCode (cname = "GCRY_KDF_SCRYPT")] SCRYPT,
      [CCode (cname = "GCRY_KDF_ARGON2")] ARGON2,
      [CCode (cname = "GCRY_KDF_BALLOON")] BALLOON,
    }

  [CCode (cheader_filename = "gcryptapi.h", lower_case_cprefix = "gcrypt_api_packed_")] [Compact (opaque = true)]

  namespace Packed
    {
      [CCode (array_length_pos = 3.1, array_length_type = "guint")]
      internal static uint8[] compact (Scalar x, Scalar y, Scalar z, out void* xp, out uint xB, out void* yp, out uint yB, out void* zp, out uint zB);
      internal static bool extract ([CCode (array_length_pos = 1.1, array_length_type = "guint")] uint8[] buffer, out void* xp, out uint xB, out void* yp, out uint yB, out void* zp, out uint zB);
    }

  [CCode (cname = "struct gcry_mpi_point", cheader_filename = "gcryptapi.h", free_function = "gcry_mpi_point_release")]
  [Compact (opaque = true)]

  internal class Point
    {
      [CCode (cname = "gcry_mpi_point_new")]
      public Point (uint nbits = 0);
      [CCode (array_length_pos = 1.1, array_length_type = "guint", type = "gpointer")]
      public uint8[] export () throws GLib.Error;
      [CCode (cname = "gcry_mpi_point_get", instance_pos = 3.1)]
      public void @get (Scalar x, Scalar y, Scalar z);
      [CCode (cname = "gcry_mpi_point_set")]
      public void @set (Scalar x, Scalar y, Scalar z);

      public Point.unpack (uint8[] buffer) throws GLib.Error
        {
          this ();
          void* xp, yp, zp;
          uint xB, yB, zB;

          Packed.extract (buffer, out xp, out xB, out yp, out yB, out zp, out zB);

          unowned var xb = (uint8[]) (uint8*) xp; xb.length = (int) xB;
          unowned var yb = (uint8[]) (uint8*) yp; yb.length = (int) yB;
          unowned var zb = (uint8[]) (uint8*) zp; zb.length = (int) zB;
          var x = Scalar.parse (ExternalFormat.USG, xb);
          var y = Scalar.parse (ExternalFormat.USG, yb);
          var z = Scalar.parse (ExternalFormat.USG, zb);
          @set (x, y, z);
        }

      public static int cmp (Point a, Point b)
        {
          uint different = 0;
          var xa = new Scalar (), ya = new Scalar (), za = new Scalar ();
          var xb = new Scalar (), yb = new Scalar (), zb = new Scalar ();

          a.@get (xa, ya, za);
          b.@get (xb, yb, zb);

          different += Scalar.cmp (xa, xb) == 0 ? 0 : 1;
          different += Scalar.cmp (ya, yb) == 0 ? 0 : 1;
          different += Scalar.cmp (za, zb) == 0 ? 0 : 1;
          return (int) different;
        }

      public uint8[] pack () throws GLib.Error
        {
          Scalar x, y, z;
          uint xB, yB, zB;
          void* xp, yp, zp;

          @get (x = new Scalar (), y = new Scalar (), z = new Scalar ());

          var ar = (uint8[]) Packed.compact (x, y, z, out xp, out xB, out yp, out yB, out zp, out zB);

          unowned var xb = (uint8[]) (uint8*) xp; xb.length = (int) xB;
          unowned var yb = (uint8[]) (uint8*) yp; yb.length = (int) yB;
          unowned var zb = (uint8[]) (uint8*) zp; zb.length = (int) zB;
          x.to_buffer (ExternalFormat.USG, xb);
          y.to_buffer (ExternalFormat.USG, yb);
          z.to_buffer (ExternalFormat.USG, zb);
          return (owned) ar;
        }
    }

  [CCode (cname = "int", cheader_filename = "gcryptapi.h")]

  internal enum PrimeCheckMode
    {
      [CCode (cname = "GCRY_PRIME_CHECK_AT_FINISH")] AT_FINISH,
      [CCode (cname = "GCRY_PRIME_CHECK_AT_GOT_PRIME")] AT_GOT_PRIME,
      [CCode (cname = "GCRY_PRIME_CHECK_AT_MAYBE_PRIME")] AT_MAYBE_PRIME,
    }

  [CCode (cname = "gcry_prime_check_func_t", cheader_filename = "gcryptapi.h", delegate_target_pos = 0.9, scope = "call", type = "int")]

  internal delegate int PrimeCheckFunc (PrimeCheckMode mode, Scalar candidate);

  [Flags]
  [CCode (cname = "int", cheader_filename = "gcryptapi.h")]

  public enum PrimeGeneratorFlags
    {
      [CCode (cname = "GCRY_PRIME_FLAG_SECRET")] SECRET,
      [CCode (cname = "GCRY_PRIME_FLAG_SPECIAL_FACTOR")] SPECIAL_FACTOR,
    }

  [CCode (cname = "gcry_random_level_t", cheader_filename = "gcryptapi.h")]

  public enum RandomnessLevel
    {
      [CCode (cname = "GCRY_WEAK_RANDOM")] WEAK,
      [CCode (cname = "GCRY_STRONG_RANDOM")] STRONG,
      [CCode (cname = "GCRY_VERY_STRONG_RANDOM")] VERY_STRONG,
    }

  [CCode (cname = "struct gcry_mpi", cheader_filename = "gcryptapi.h", free_function = "gcry_mpi_release")]
  [Compact (opaque = true)]

  internal class Scalar
    {
      public uint nbits { [CCode (cname = "gcry_mpi_get_nbits")] get; }
      [CCode (cname = "gcry_mpi_new")]
      public Scalar (uint nbits = 0);
      [CCode (cname = "gcry_mpi_cmp")]
      public static int cmp (Scalar a, Scalar b);
      [CCode (cname = "gcry_mpi_mod")]
      public static void mod (Scalar result, Scalar dividend, Scalar divisor);
      [CCode (cname = "gcry_prime_generate")]
      public static ErrorCode prime_generate (out Scalar prime, uint nbits, uint factor_bits, [CCode (array_length = false, array_null_terminated = true)] out Scalar[] factors, PrimeCheckFunc? check_func, RandomnessLevel level, PrimeGeneratorFlags flags);
      [CCode (cname = "gcry_mpi_print", instance_pos = 4.1)]
      public ErrorCode print (ExternalFormat format, void* buffer, size_t buflen, out size_t written = null);
      [CCode (cname = "gcry_mpi_scan")]
      public static ErrorCode scan (out Scalar scalar, ExternalFormat format, void* buffer, size_t buflen, out size_t unscanned = null);

      public static Scalar parse (ExternalFormat format, uint8[] buffer, out size_t unscanned = null) throws GLib.Error
        {
          Scalar n;
          ErrorCode code = scan (out n, format, & buffer [0], buffer.length, out unscanned);

          if (GLib.unlikely (code != 0))

            throw new GLib.Error.literal (ErrorCode.domain (), (int) code, code.to_string ());
          return (owned) n;
        }

      public static Scalar random_prime (uint nbits, uint factor_bits, [CCode (array_length = false, array_null_terminated = true)] out Scalar[] factors, PrimeCheckFunc? check_func, RandomnessLevel level, PrimeGeneratorFlags flags) throws GLib.Error
        {
          Scalar scalar;
          ErrorCode code = prime_generate (out scalar, nbits, factor_bits, out factors, check_func, level, flags);

          if (GLib.unlikely (code != 0))

            throw new GLib.Error.literal (ErrorCode.domain (), (int) code, code.to_string ());
          return (owned) scalar;
        }

      public bool to_buffer (ExternalFormat format, uint8[] buffer, out size_t written = null) throws GLib.Error
        {
          var code = print (format, (void*) & buffer [0], buffer.length, out written);

          if (GLib.unlikely (code != 0))

            throw new GLib.Error.literal (ErrorCode.domain (), (int) code, code.to_string ());
          return true;
        }
    }
}
