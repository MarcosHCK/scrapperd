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
#include <config.h>
#include <dhprotc.h>
#include <gcrypt.h>

G_DEFINE_QUARK (gcrypt-error-quark, _gcry_error);
G_LOCK_DEFINE_STATIC (gcry_strerror);

void _gcry_init (void)
{
  static gsize __good_flag__ = 0;

  if (g_once_init_enter (&__good_flag__))
    {
      gcry_check_version (GCRYPT_VERSION);
      g_once_init_leave (&__good_flag__, 1);
    }
}

const gchar* _gcry_strerror (gcry_error_t code)
{
  const gchar* message;
  G_LOCK (gcry_strerror);
  message = gcry_strerror (code);
  return (G_UNLOCK (gcry_strerror), message);
}
