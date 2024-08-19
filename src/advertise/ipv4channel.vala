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

      private GLib.List<GLib.SocketAddress> ifaces;
      private GLib.Socket socket;

      public Ipv4Channel () throws GLib.Error
        {
          Object ();
          init ();
        }

      public bool bind (GLib.SocketAddress address) throws GLib.Error
        {
          return socket.bind (address, true);
        }

      private bool bind_x_port (bool pickany, uint16 port) throws GLib.Error
        {
          GLib.SocketAddress address;
          var any = (int) 0;
          var family = (SocketFamily) GLib.SocketFamily.IPV4;

          foreach (unowned var info in Netdis.Interface.enumerate (family)) if (info.broadcast != null)
            {
              assert (info.broadcast is InetSocketAddress);
              var socket_address = (SocketAddress) info.broadcast;
              var inet_address = (InetAddress) ((GLib.InetSocketAddress) socket_address).address;

              ifaces.append (address = new GLib.InetSocketAddress (inet_address, port));
              any = (pickany == false ? bind (address) : try_bind (address)) ? 1 : 0;
            }

          return any > 0;
        }

      public void bind_all_port (uint16 port) throws GLib.Error
        {
          bind_x_port (false, port);
        }

      public bool bind_any_port (uint16 port) throws GLib.Error
        {
          return bind_x_port (true, port);
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

      public bool try_bind (GLib.SocketAddress address) throws GLib.Error
        {
          try { socket.bind (address, true); } catch (GLib.Error e)
            {
              if (e.matches (GLib.IOError.quark (), GLib.IOError.INVALID_ARGUMENT) == false)

                throw (owned) e;
              else
                {
                  unowned var code = e.code;
                  unowned var domain = e.domain.to_string ();
                  unowned var message = e.message.to_string ();

                  warning ("%s: %u: %s", domain, code, message);
                }
            }

          return true;
        }
    }
}
