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
using Kademlia;

[CCode (cprefix = "ScrapperdViewer", lower_case_cprefix = "scrapperd_viewer_")]

namespace ScrapperD.Viewer
{
  public enum RoleTargetType
    {
      
      CONSOLE,
      FILE,
      POPUP,
    }

  public class RoleTarget : RoleTransport
    {
      public string target { get; private set; }
      public RoleTargetType target_type { get; private set; }

      private RoleTarget () { }

      public RoleTarget.parse (string value) throws GLib.Error
        {
          RoleTransport.parse<RoleTargetType> (value, RoleTargetType.POPUP, out _target, out _target_type);
        }

      public async void set_output (GLib.Value? value, GLib.Cancellable? cancellable) throws GLib.Error
        {
          if (value.holds (typeof (GLib.Bytes)) == false)
            {
              throw new IOError.INVALID_DATA ("invalid value type returned from peer");
            }

          switch (target_type)
            {
              case RoleTargetType.CONSOLE:
                {
                  var bytes = (GLib.Bytes) value.dup_boxed ();
                  var variant = new GLib.Variant.from_bytes (GLib.VariantType.BYTESTRING, bytes, false);
                  print ("%s\n", variant.print_string (null, false).str);
                  break;
                }

              case RoleTargetType.FILE:
                {
                  var bytes = (GLib.Bytes) value.dup_boxed ();
                  var file = GLib.File.new_for_commandline_arg (target);
                  var file_stream = yield file.replace_async (null, false, 0, GLib.Priority.LOW, cancellable);
                  var byte_stream = new GLib.MemoryInputStream.from_bytes (bytes);

                  unowned var flags1 = GLib.OutputStreamSpliceFlags.CLOSE_SOURCE;
                  unowned var flags2 = GLib.OutputStreamSpliceFlags.CLOSE_TARGET;
                  unowned var flags = flags1 | flags2;

                  yield file_stream.splice_async (byte_stream, flags, GLib.Priority.LOW, cancellable);
                  break;
                }

              default: assert_not_reached ();
            }
        }
    }
}
