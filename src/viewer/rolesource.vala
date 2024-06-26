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
  public enum RoleSourceType
    {
      DATA,
      FILE,
      NULL,
      VERBATIM,
    }

  public class RoleSource : RoleTransport
    {
      public string source { get; private set; }
      public RoleSourceType source_type { get; private set; }

      private RoleSource () { }

      public RoleSource.parse (string value) throws GLib.Error
        {
          RoleTransport.parse<RoleSourceType> (value, RoleSourceType.DATA, out _source, out _source_type);
        }

      public async Key get_key (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          switch (source_type)
            {
              case RoleSourceType.DATA: return new Key.from_data (source.data);

              case RoleSourceType.FILE:
                {
                  var file = GLib.File.new_for_commandline_arg (source);
                  var stream = file.read (cancellable);
                  var builder = new KeyBuilder ();
                  uint8 buffer [256];
                  unowned var got = (uint8[]) & buffer [0];
                  unowned var read = (size_t) 0;

                  while (true)
                    {
                      got.length = buffer.length;

                      if ((yield stream.read_all_async (got, GLib.Priority.LOW, cancellable, out read)) && (got.length = (int) read) > 0)

                        builder.update ((uchar[]) & got [0], got.length);
                      else
                        {
                          break;
                        }
                    }

                  return builder.end ();
                }

              case RoleSourceType.NULL:

                throw new RoleTransportError.UNKNOWN_TYPE ("unsupported source '%s' for data", source_type.to_string ());

              case RoleSourceType.VERBATIM:

                return new Key.parse (source, -1);

              default: assert_not_reached ();
            }
        }

      public async GLib.Value? get_input (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          switch (source_type)
            {
              case RoleSourceType.DATA:
                {
                  var bytes = new GLib.Bytes (source.data);
                  var value = GLib.Value (typeof (GLib.Bytes));
                    value.take_boxed ((owned) bytes);
                  return (owned) value;
                }

              case RoleSourceType.FILE:
                {
                  var file = GLib.File.new_for_commandline_arg (source);
                  var file_stream = yield file.read_async (GLib.Priority.LOW, cancellable);
                  var byte_stream = new GLib.MemoryOutputStream.resizable ();

                  unowned var flags1 = GLib.OutputStreamSpliceFlags.CLOSE_SOURCE;
                  unowned var flags2 = GLib.OutputStreamSpliceFlags.CLOSE_TARGET;
                  unowned var flags = flags1 | flags2;

                  yield byte_stream.splice_async (file_stream, flags, GLib.Priority.LOW, cancellable);

                  var bytes = byte_stream.steal_as_bytes ();
                  var value = GLib.Value (typeof (GLib.Bytes));
                    value.take_boxed ((owned) bytes);
                  return (owned) value;
                }

              case RoleSourceType.NULL: return null;

              case RoleSourceType.VERBATIM:

                throw new RoleTransportError.UNKNOWN_TYPE ("unsupported source '%s' for data", source_type.to_string ());

              default: assert_not_reached ();
            }
        }
    }
}
