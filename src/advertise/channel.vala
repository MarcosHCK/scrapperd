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

[CCode (cprefix = "Adv", lower_case_cprefix = "adv_")]

namespace Advertise
{
  [CCode (scope = "notified")]

  public delegate bool ChannelSourceFunc (Channel channel);

  public interface Channel : GLib.Object
    {
      public abstract ChannelSource create_source (GLib.Cancellable? cancellable);
      public abstract async GenericArray<GLib.Bytes> recv (GLib.Cancellable? cancellable) throws GLib.Error;
      public abstract async bool send (GLib.Bytes contents, GLib.Cancellable? cancellable) throws GLib.Error;
    }

  [Compact (opaque = true)]

  public class ChannelSource : GLib.Source
    {
      public Channel channel { get; private set; }

      public ChannelSource (Channel channel)
        {
          this.channel = channel;
        }

      public ChannelSource.with_child (Channel channel, GLib.Source child_source)
        {
          this.channel = channel;
          add_child_source (child_source);
        }

      protected override bool check ()
        {
          return false;
        }

      protected override bool dispatch (GLib.SourceFunc? callback)
        {
          if (callback == null)

            return GLib.Source.CONTINUE;
          else
            return ((ChannelSourceFunc) callback) (channel);
        }

      protected override bool prepare (out int timeout)
        {
          timeout = 0;
          return false;
        }

      public new void set_callback ([CCode (type = "GSourceFunc")] owned ChannelSourceFunc func)
        {
          base.set_callback ((GLib.SourceFunc) (owned) func);
        }
    }
}
