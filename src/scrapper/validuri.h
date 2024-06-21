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
#ifndef __SCRAPPERD_SCRAPPER_VALIDURI__
#define __SCRAPPERD_SCRAPPER_VALIDURI__ 1
#include <glib.h>
#include <libsoup/soup.h>

#if __cplusplus
extern "C" {
#endif // __cplusplus

  #define _string_equals(from,static_) (G_GNUC_EXTENSION ({ \
 ; \
      const gchar* __from = (from); \
      const gchar* __static = (static_); \
 ; \
      g_intern_static_string (__static) == __from || g_str_equal (__from, __static); \
    }))

  static __inline gboolean _g_uri_is_valid (GUri* uri)
    {
      const gchar* scheme = g_uri_get_scheme (uri);

      if (FALSE == (_string_equals (scheme, "http") || _string_equals (scheme, "https")))
        return FALSE;
      if (g_uri_get_host (uri) == NULL || g_uri_get_path (uri) == NULL)
        return FALSE;

      return TRUE;
    }

  #undef _string_equals

#if __cplusplus
}
#endif // __cplusplus

#endif // __SCRAPPERD_SCRAPPER_VALIDURI__
