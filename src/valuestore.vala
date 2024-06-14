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
  public interface ValueStore : GLib.Object
    {

      public virtual async bool insert_value (Key id, GLib.Value? value = null, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          throw new IOError.FAILED ("unimplemented");
        }

      public virtual async GLib.Value? lookup_value (Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          throw new IOError.FAILED ("unimplemented");
        }
    }
}
