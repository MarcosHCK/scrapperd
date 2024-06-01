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
#include <value.h>

G_DEFINE_BOXED_TYPE (KValue, k_value, k_value_copy, k_value_free)

#define k_value_new() (g_slice_new0 (KValue))

KValue* k_value_copy (KValue* value)
{
  g_return_val_if_fail (value != NULL, NULL);

  if (k_value_is_inmediate (value))

    return k_value_new_inmediate (value->inmediate);
  else
    return k_value_new_delegated (value->neighbors, value->n_neighbors);
}

void k_value_free (KValue* value)
{
  if (value != NULL)
    {
      if (k_value_is_inmediate (value))
        {
          g_bytes_unref (value->inmediate);
        }
      else
        {
          guint i;

          for (i = 0; i < value->n_neighbors; ++i)

            k_key_free (value->neighbors [i]);

          g_free (value->neighbors);
        }

      g_slice_free (KValue, value);
    }
}

KValue* k_value_new_delegated (KKey** keys, guint n_keys)
{
  g_return_val_if_fail (keys != NULL, NULL);
  KValue* value = k_value_new ();
  guint i;

  for (i = 0, value->neighbors = g_new (KKey*, n_keys); i < n_keys; ++i)

    value->neighbors [i] = k_key_copy (keys [i]);

  return value;
}

KValue* k_value_new_inmediate (GBytes* bytes)
{
  g_return_val_if_fail (bytes != NULL, NULL);
  KValue* value;

  return ((value = k_value_new ())->inmediate = g_bytes_ref (bytes), value);
}
