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
  public class Ipv4Channel : GLib.Object, Channel, GLib.Initable
    {
      public const uint16 DEFAULT_PORT = 33332;

      public uint16 port { get; construct; }
      private GLib.List<GLib.SocketAddress> ifaces;
      private GLib.Socket socket;

      public Ipv4Channel (uint16 port) throws GLib.Error
        {
          Object (port : port);
          init ();
        }

      public ChannelSource create_source (GLib.Cancellable? cancellable)
        {
          var condition = (int) GLib.IOCondition.IN;
          var child_source = (Source) socket.datagram_create_source (condition, cancellable);
          child_source.set_callback (dummy_callback);
          return new ChannelSource.with_child (this, child_source);
        }

      static bool dummy_callback ()
        {
          return GLib.Source.CONTINUE;
        }

      public bool init (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var family = (SocketFamily) GLib.SocketFamily.IPV4;
          var protocol = (SocketProtocol) GLib.SocketProtocol.UDP;
          var type = (SocketType) GLib.SocketType.DATAGRAM;

          ifaces = new GLib.List<GLib.SocketAddress> ();
          socket = new GLib.Socket (family, type, protocol);

          socket.broadcast = true;

          ifaces.append (new InetSocketAddress (new InetAddress.from_string ("127.255.255.255"), port));

          foreach (unowned var address in ifaces) socket.bind (address, true);
          return true;
        }

      [CCode (cheader_filename = "ipv4channel.h")]

      extern async GenericArray<Bytes> recv_from (Socket socket, List<SocketAddress> ifaces, Cancellable? cancellable) throws Error; 

      public async GenericArray<GLib.Bytes> recv (GLib.Cancellable? cancellable) throws GLib.Error
        {
          return yield recv_from (socket, ifaces, cancellable);
        }

      [CCode (cheader_filename = "ipv4channel.h")]

      extern async bool send_to (Socket socket, List<SocketAddress> ifaces, Bytes contents, Cancellable? cancellable) throws Error;

      public async bool send (GLib.Bytes contents, GLib.Cancellable? cancellable) throws GLib.Error
        {
          return yield send_to (socket, ifaces, contents, cancellable);
        }
    }
}
