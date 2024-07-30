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
  [Compact (opaque = true)]

  public class Ad
    {
      public string? name { get; private set; }
      public string? description { get; private set; }
      public Protocol[] protocols { get; private set; }

      public Ad (string? name, string? description, owned Protocol[] protocols)
        {
          this.description = description;
          this.name = name;
          this.protocols = (owned) protocols;
        }

      internal Ad.from_array (string? name, string? description, GenericArray<Protocol> ar)
        {
          unowned Protocol[] ar_ = ar.data;
          this (name, description, ar_.copy ());
        }
    }

  public class Hub : GLib.Object
    {
      public string? description { get; set; }
      public string? name { get; set; }

      private GLib.List<Channel> channels = new GLib.List<Channel> ();
      private Protocols protocols = new Protocols ();

      construct
        {
          bind_property ("description", protocols, "description", GLib.BindingFlags.SYNC_CREATE);
          bind_property ("name", protocols, "name", GLib.BindingFlags.SYNC_CREATE);
        }

      public void add_channel (Channel channel)
        {
          if (channels.find (channel) == null)

            channels.append (channel);
        }

      public void add_protocol (Protocol proto)
        {
          protocols.add_protocol (proto);
        }

      public async bool advertise (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          Json.Generator generator;
          Json.Node node = Json.gobject_serialize (protocols);
          (generator = new Json.Generator ()).set_root (node);
          var converter = new ZlibCompressor (GLib.ZlibCompressorFormat.RAW, 3);
          var stream1 = new GLib.MemoryOutputStream.resizable ();
          var stream2 = new GLib.ConverterOutputStream (stream1, converter);

          generator.indent = 0;
          generator.pretty = false;

          generator.to_stream (stream2, cancellable);

          stream2.close (cancellable);
          stream1.close (cancellable);

          var contents = (Bytes) stream1.steal_as_bytes ();

          foreach (unowned var channel in channels)

            yield channel.send (contents, cancellable);
          return true;
        }

      public void ensure_protocol (GLib.Type gtype) requires (gtype.is_a (typeof (Protocol)))
        {
          gtype.ensure ();
        }

      public async Ad? peek (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          foreach (unowned var channel in channels) try
            {
              var bytes = (Bytes) yield channel.recv (cancellable);
              var converter = new GLib.ZlibDecompressor (GLib.ZlibCompressorFormat.RAW);
              var stream1 = new GLib.MemoryInputStream.from_bytes (bytes);
              var stream2 = new GLib.ConverterInputStream (stream1, converter);
              var stream3 = new GLib.DataInputStream (stream2);

              size_t length;
              string data = yield stream3.read_line_async (GLib.Priority.LOW, cancellable, out length);
              var gtype = (Type) typeof (Protocols);
              var protos = (Protocols) Json.gobject_from_data (gtype, data, (ssize_t) length);

              unowned var description = protos.description;
              unowned var name = protos.name;
              unowned var ar = protos.protocols;

              return new Ad.from_array (name, description, ar);
            }
          catch (GLib.IOError e)
            {
              if (e.code == GLib.IOError.WOULD_BLOCK)

                continue;
              else
                throw (owned) e;
            }

          return null;
        }

      public void remove_channel (Channel channel)
        {
          channels.remove (channel);
        }

      public void remove_protocol (Protocol proto)
        {
          protocols.remove_protocol (proto);
        }

      public void remove_protocol_by_name (string name)
        {
          protocols.remove_protocol_by_name (name);
        }
    }
}
