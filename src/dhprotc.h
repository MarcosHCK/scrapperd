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
#ifndef __DH_PROTC__
#define __DH_PROTC__ 1
#include <glib.h>
#include <gcrypt.h>

typedef struct gcry_context DHCurve;
typedef struct gcry_mpi_point DHPoint;
typedef struct gcry_mpi DHScalar;

#if __cplusplus
extern "C" {
#endif // __cplusplus

  G_GNUC_INTERNAL void _gcry_init (void);
  G_GNUC_INTERNAL GQuark _gcry_error_quark (void);
  G_GNUC_INTERNAL const gchar* _gcry_strerror (gcry_error_t code);

  static __inline gpointer dh_packed_compact (gcry_mpi_t x, gcry_mpi_t y, gcry_mpi_t z, guint* buflen, gpointer* xp, guint* xB, gpointer* yp, guint* yB, gpointer* zp, guint* zB)
    {
      g_return_val_if_fail (x != NULL, NULL);
      g_return_val_if_fail (y != NULL, NULL);
      g_return_val_if_fail (z != NULL, NULL);
      guint xb, yb, zb, bytes;
      gpointer xr, yr, zr, buffer;

      bytes = sizeof (guint16) * 3;
      xr = G_STRUCT_MEMBER_P (NULL, bytes); bytes += (*xB = (((xb = gcry_mpi_get_nbits (x)) + 7) >> 3));
      yr = G_STRUCT_MEMBER_P (NULL, bytes); bytes += (*yB = (((yb = gcry_mpi_get_nbits (y)) + 7) >> 3));
      zr = G_STRUCT_MEMBER_P (NULL, bytes); bytes += (*zB = (((zb = gcry_mpi_get_nbits (z)) + 7) >> 3));
      buffer = g_malloc (bytes);
      *xp = G_STRUCT_MEMBER_P (buffer, (guintptr) xr); ((guint16*) buffer) [0] = GUINT16_TO_BE (xb);
      *yp = G_STRUCT_MEMBER_P (buffer, (guintptr) yr); ((guint16*) buffer) [1] = GUINT16_TO_BE (yb);
      *zp = G_STRUCT_MEMBER_P (buffer, (guintptr) zr); ((guint16*) buffer) [2] = GUINT16_TO_BE (zb);
      return (*buflen = bytes, buffer);
    }

  static __inline gboolean dh_packed_extract (gpointer buffer, gsize buflen, gpointer* xp, guint* xB, gpointer* yp, guint* yB, gpointer* zp, guint* zB)
    {
      g_return_val_if_fail (buffer != NULL, FALSE);
      g_return_val_if_fail (buflen >= 3 * sizeof (guint16), FALSE);
      guint xb, yb, zb, bytes;

      bytes = 3 * sizeof (guint16);
      *xp = G_STRUCT_MEMBER_P (buffer, bytes); bytes += (*xB = ((xb = GUINT16_FROM_BE (((guint16*) buffer) [0])) + 7) >> 3);
      *yp = G_STRUCT_MEMBER_P (buffer, bytes); bytes += (*yB = ((yb = GUINT16_FROM_BE (((guint16*) buffer) [1])) + 7) >> 3);
      *zp = G_STRUCT_MEMBER_P (buffer, bytes); bytes += (*zB = ((zb = GUINT16_FROM_BE (((guint16*) buffer) [2])) + 7) >> 3);
      g_return_val_if_fail (buflen == bytes, FALSE);
      return TRUE;
    }

#if __cplusplus
}
#endif // __cplusplus

#endif // __DH_PROTC__
