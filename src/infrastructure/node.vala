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

[CCode (cprefix = "Scrapperd", lower_case_cprefix = "scrapperd_")]

namespace ScrapperD
{
  [DBus (name = "org.hck.ScrapperD.Node.Infrastructure")]
  public interface InstanceNode : GLib.Object
    {
      [DBus (name = "IsMaster")] public abstract bool is_master { get; }
    }

  internal class InstanceNodeImpl : GLib.Object, InstanceNode
    {
      public bool master { get; construct; }

      public bool is_master { get { return master; } }

      public InstanceNodeImpl (bool master = false)
        {
          Object (master : master);
        }
    }
}
