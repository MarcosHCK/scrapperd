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

[CCode (cprefix = "K", lower_case_cprefix = "k_")]

namespace Kademlia
{
  public interface BaseCrawler : GLib.Object
    {
      [CCode (scope = "notified")]

      internal static CompareDataFunc<Key> create_sorter (owned Key key)
        {
          CompareDataFunc<Key> sorter = (a, b) =>
            {
              return Key.distance (a, key) - Key.distance (b, key);
            };

          return (owned) sorter;
        }
    }
}
