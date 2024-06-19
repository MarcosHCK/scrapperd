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
#ifndef __KADEMLIA_KEYVAL__
#define __KADEMLIA_KEYVAL__ 1
#include <glib.h>

#define K_KEY_VAL_BITLEN 160
#define K_KEY_VAL_CHECKSUM G_CHECKSUM_SHA1
typedef union _KKeyVal KKeyVal;

#if __cplusplus
extern "C" {
#endif // __cplusplus

  union _KKeyVal
    {
      guint8 bytes [K_KEY_VAL_BITLEN >> 3];
      guint16 shorts [K_KEY_VAL_BITLEN >> 4];
      guint32 longs [K_KEY_VAL_BITLEN >> 5];
      guint64 quads [K_KEY_VAL_BITLEN >> 6];
    };

  #define k_key_val_destroy(val)

  G_STATIC_ASSERT (0 == (K_KEY_VAL_BITLEN & 0x3));

  #define k_key_val_nth_bit(val,nth) (G_GNUC_EXTENSION ({ \
 ; \
      const KKeyVal* __val = (val); \
      const gint __nth_ = (nth); \
      const guint __nth = __nth_ > 0 ? __nth_ : K_KEY_VAL_BITLEN + __nth_; \
      (__val->bytes [__nth >> 3] >> (__nth & 0x3)) & 1; \
    }))

  #define k_key_val_copy(src,dst) (G_GNUC_EXTENSION ({ \
 ; \
      const KKeyVal* __src = (src); \
      KKeyVal* __dst = (dst); \
      (memcpy (__dst, __src, sizeof (*__dst)), FALSE); \
    }))

  static __inline void k_key_val_xor (KKeyVal* d, const KKeyVal* a, const KKeyVal* b)
    {
      guint i;
  #if GLIB_SIZEOF_VOID_P >= 8
      /* 64 bits computer */
      for (i = 0; i < G_N_ELEMENTS (a->quads); ++i)
        d->quads[i] = a->quads[i] ^ b->quads[i];
      const int first = G_SIZEOF_MEMBER (KKeyVal, quads);
  #else  // GLIB_SIZEOF_VOID_P < 8
      /* 32 bits computer */
      for (i = 0; i < G_N_ELEMENTS (a->longs); ++i)
        d->longs[i] = a->longs[i] ^ b->longs[i];
      const int first = G_SIZEOF_MEMBER (KKeyVal, longs);
  #endif // GLIB_SIZEOF_VOID_P

      for (i = first; i < G_N_ELEMENTS (a->bytes); ++i)
        d->bytes[i] = a->bytes[i] ^ b->bytes[i];
    }

  static const gchar k_key_val_logtable [] =
    {
      -1, 0, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3,
       4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
       5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
       5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
       6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
       6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
       6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
       6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
       7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
       7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
       7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
       7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
       7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
       7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
       7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
       7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
    };

  #define _2exp(n) (2<<(((n))-1))

  G_STATIC_ASSERT (_2exp (sizeof (gchar) << 3) == G_N_ELEMENTS (k_key_val_logtable));
  #undef _2exp

  static __inline gint k_key_val_log (const KKeyVal* a, const KKeyVal* b)
    {
      KKeyVal xor;
      guint8 c;
      guint i, l;

      k_key_val_xor (&xor, a, b);

      for (i = 0; i < (l = K_KEY_VAL_BITLEN >> 3); ++i)
        {
          if ((c = xor.bytes [i]) > 0)

            return ((l - (i + 1)) << 3) + k_key_val_logtable [c];
        }
      return -1; /* equals */
    }

#if __cplusplus
}
#endif // __cplusplus

#endif // __KADEMLIA_KEYVAL__
