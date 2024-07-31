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
      public List<unowned Channel> channels { owned get { return _channels.copy (); } }
      public string? description { get; set; }
      public string? name { get; set; }

      private GLib.List<Channel> _channels = new GLib.List<Channel> ();
      private Protocols protocols = new Protocols ();

      public signal void added_channel (Channel channel);
      public signal void added_protocol (Protocol protocol);
      public signal void removed_channel (Channel channel);
      public signal void removed_protocol (Protocol protocol);

      construct
        {
          bind_property ("description", protocols, "description", GLib.BindingFlags.SYNC_CREATE);
          bind_property ("name", protocols, "name", GLib.BindingFlags.SYNC_CREATE);
        }

      public void add_channel (Channel channel)
        {
          if (_channels.find (channel) == null)

            _channels.append (channel);
        }

      public void add_protocol (Protocol proto) requires (protocols.protocols.find (proto) == false)
        {
          protocols.protocols.add (proto);
          added_protocol (proto);
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

          foreach (unowned var channel in _channels)

            yield channel.send (contents, cancellable);
          return true;
        }

      public void ensure_protocol (GLib.Type gtype) requires (gtype.is_a (typeof (Protocol)))
        {
          gtype.ensure ();
        }

      public async Ad[] peek (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var ads = new GenericArray<Ad> ();

          foreach (unowned var channel in _channels) try
            {
              var ar = (GenericArray<Ad>) yield peek_channel (channel, cancellable);
              ads.extend_and_steal ((owned) ar);
            }
          catch (GLib.IOError e)
            {
              if (e.code == GLib.IOError.WOULD_BLOCK)

                continue;
              else
                throw (owned) e;
            }

          return ads.steal ();
        }

      internal static async GenericArray<Ad> peek_channel (Channel channel, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var ads = new GenericArray<Ad> ();

          foreach (unowned var bytes in yield channel.recv (cancellable))
            {
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

              ads.add (new Ad.from_array (name, description, ar));
            }

          return (owned) ads;
        }

      public void remove_channel (Channel channel)
        {
          _channels.remove (channel);
        }

      public void remove_protocol (Protocol proto)
        {
          if (protocols.protocols.remove (proto)) removed_protocol (proto);
        }

      public void remove_protocol_by_name (string name)
        {
          var list = new SList<uint?> ();
          var protocols = (GenericArray<Protocol>) this.protocols.protocols;
          for (int i = 0; i < protocols.length; ++i) if (name == protocols [i].name) list.append (i);
          foreach (unowned var k in list) removed_protocol (protocols.steal_index (k));
        }
    }
}
