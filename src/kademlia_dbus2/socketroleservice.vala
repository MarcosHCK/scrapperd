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

[CCode (cprefix = "KDBus", lower_case_cprefix = "k_dbus_")]

namespace Kademlia.DBus
{
  public const uint16 DEFAULT_PORT = 33334;

  struct RegIds
    {
      public uint node_regid;
      public uint[] role_regids;

      public RegIds (uint node_regid, owned uint[] role_regids)
        {
          this.node_regid = node_regid;
          this.role_regids = (owned) role_regids;
        }
    }

  public class SocketRoleService : RoleService
    {
      private GLib.ThreadedSocketService socket_service;

      construct
        {
          socket_service = new ThreadedSocketService ((int) GLib.get_num_processors ());

          socket_service.stop ();
          socket_service.run.connect (on_incoming);
        }

      public SocketRoleService (AddressService address_service)
        {
          Object (address_service : address_service);
        }

      public async ValuePeer create_proxy_at (string host_and_port, uint16 default_port, string role, GLib.Cancellable? cancellable) throws GLib.Error
        {
          unowned AddressProvider address_provider = address_service;
          unowned AddressRegistry address_registry = address_service;
          unowned RoleProvider role_provider = this;
          unowned RoleRegistry role_registry = this;

          var node = (Node?) yield reach (Address (host_and_port, default_port), cancellable);
          var proxy = new PeerImplProxy (address_provider, null, address_registry, role_provider, role_registry);

          foreach (unowned var keyref in yield node.list_ids (cancellable))
            {
              var id = (Key) new Key.verbatim (keyref.value);
              var rol = (Role) yield role_provider.lookup (id, cancellable);

              if (role == rol.role) yield proxy.join (id, cancellable);
            }

          return (owned) proxy;
        }

      public async bool join_at (string host_and_port, uint16 default_port, string? role, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          unowned RoleProvider role_provider = this;

          var any = 0;
          var node = yield reach (Address (host_and_port, default_port), cancellable);

          foreach (unowned var keyref in yield node.list_ids (cancellable))
            {
              var id = (Key) new Key.verbatim (keyref.value);
              var rol = (Role) yield role_provider.lookup (id, cancellable);

              if (role == null || role == rol.role)

                any += (yield join (id, rol.role, cancellable)) ? 1 : 0;
            }

          return any > 0;
        }

      private bool on_incoming (GLib.SocketConnection socket_connection, GLib.Object? source_object)
        {
          on_incoming_async.begin (socket_connection, null, (o, res) =>
            {
              try { ((SocketRoleService) o).on_incoming_async.end (res); } catch (GLib.Error e)
                {
                  unowned var code = e.code;
                  unowned var domain = e.domain.to_string ();
                  unowned var message = e.message.to_string ();

                  warning ("incoming connection error: %s: %u: %s", domain, code, message);
                }
            });

          return true;
        }

      private async Node? on_incoming_async (GLib.SocketConnection socket_connection, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var flags1 = GLib.DBusConnectionFlags.AUTHENTICATION_ALLOW_ANONYMOUS;
          var flags2 = GLib.DBusConnectionFlags.AUTHENTICATION_SERVER;
          var flags3 = GLib.DBusConnectionFlags.DELAY_MESSAGE_PROCESSING;
          var flags = flags1 | flags2 | flags3;
          var guid = GLib.DBus.generate_guid ();
          var krypt_stream = new Krypt.IOStream ("AES", "CBC", socket_connection);
          yield krypt_stream.handshake_server (GLib.Priority.LOW, cancellable);
          var dbus = yield new GLib.DBusConnection (krypt_stream, guid, flags, null, cancellable);

          yield prepare_connection (dbus, cancellable);

          dbus.exit_on_close = false;
          dbus.start_message_processing ();

          return yield register_connection (dbus, cancellable);
        }

      public void listen_on_address (GLib.SocketAddress address, GLib.SocketType type, GLib.SocketProtocol protocol) throws GLib.Error
        {
          GLib.SocketAddress effective_address;
          socket_service.add_address (address, type, protocol, address, out effective_address);

          assert (effective_address is GLib.InetSocketAddress);
          var inet_address = ((GLib.InetSocketAddress) effective_address).address;
          var inet_port = ((GLib.InetSocketAddress) effective_address).port;

          address_service.add (null, new Address [] { Address (inet_address.to_string (), (uint16) inet_port) });
        }

      public void listen_on_port (uint16 port, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          GLib.SocketFamily families [] =
            {
              GLib.SocketFamily.IPV4,
              GLib.SocketFamily.IPV6,
            };

          foreach (unowned var family in families)
          foreach (unowned var info in Netdis.Interface.enumerate (family)) if (info.broadcast != null)
            
            if ((info.address is GLib.InetSocketAddress) == false)

              address_service.add (null, new Address [] { Address (info.address.to_string (), port) });
            else
              {
                var inet_address = ((GLib.InetSocketAddress) info.address).address;
                address_service.add (null, new Address [] { Address (inet_address.to_string (), port) });
              }

          socket_service.add_inet_port (port, null);
        }

      protected override async Node? reach (Address? address, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var flags1 = GLib.DBusConnectionFlags.AUTHENTICATION_CLIENT;
          var flags2 = GLib.DBusConnectionFlags.DELAY_MESSAGE_PROCESSING;
          var flags = flags1 | flags2;
          var socket_connection = yield reach_at (address, cancellable);
          var krypt_stream = new Krypt.IOStream ("AES", "CBC", socket_connection);
          yield krypt_stream.handshake_client (GLib.Priority.LOW, cancellable);
          var dbus = yield new GLib.DBusConnection (krypt_stream, null, flags, null, cancellable);

          yield prepare_connection (dbus, cancellable);

          dbus.exit_on_close = false;
          dbus.start_message_processing ();

          return yield register_connection (dbus, cancellable);
        }

      static async GLib.SocketConnection reach_at (Address? address, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          unowned var default_port = (uint16) address.port;
          unowned var host_and_port = (string) address.address;
          var socket_client = new GLib.SocketClient ();

          socket_client.enable_proxy = false;
          socket_client.protocol = GLib.SocketProtocol.TCP;
          socket_client.timeout = 3;
          socket_client.tls = false;
          socket_client.type = GLib.SocketType.STREAM;

          return yield socket_client.connect_to_host_async (host_and_port, default_port, cancellable);
        }

      public void start () { socket_service.start (); }
      public void stop () { socket_service.stop (); }
    }
}
