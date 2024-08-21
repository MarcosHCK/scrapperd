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
  public errordomain PeerImplError
    {
      FAILED;
      public extern static GLib.Quark quark ();
    }

  public class PeerImpl : ValuePeer
    {
      public AddressProvider address_provider { get; construct; }
      public AddressRegistry address_registry { get; construct; }
      public RoleProvider role_provider { get; construct; }
      public RoleRegistry role_registry { get; construct; }

      construct
        {
          added_contact.connect ((k) => debug ("added contact %s:(%s)", k.to_string (), id.to_string ()));
          dropped_contact.connect ((k) => debug ("dropped contact %s:(%s)", k.to_string (), id.to_string ()));
          staled_contact.connect ((k) => debug ("staled contact %s:(%s)", k.to_string (), id.to_string ()));
        }

      public PeerImpl (AddressProvider address_provider, Key? id, AddressRegistry address_registry, RoleProvider role_provider, RoleRegistry role_registry, ValueStore value_store)
        {
          Object (address_provider : address_provider, address_registry : address_registry, id : id, role_provider : role_provider, role_registry : role_registry, value_store : value_store);
        }

      private void @catch (Key peer, owned GLib.Error? e) throws GLib.Error
        {
          if (e.domain == IOError.quark ())

            switch (e.code)
              {
                case GLib.IOError.CLOSED:
                case GLib.IOError.CONNECTION_CLOSED:
                case GLib.IOError.TIMED_OUT:

                  debug ("contact lost %s (I/O layer error)", peer.to_string ());
                  role_registry.drop (peer);
                  return;
              }

          else if (e.domain == NetworkError.quark ())

            switch (e.code)
              {
                case NetworkError.RESETTED:

                  debug ("contact lost %s (network layer error)", peer.to_string ());

                  address_registry.drop (id, address_provider.lookup (id));
                  role_registry.drop (id);
                  return;
              }

          throw (owned) e;
        }

      protected virtual PeerRef get_self ()
        {
          return PeerRef (id.bytes, address_provider.locals ());
        }

      protected override async Key[] find_peer (Key peer, Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          for (int tries = 0; tries < 3; ++tries) try
            {
              var role = yield role_provider.lookup (peer, cancellable);
              var refs = yield role.find_node (get_self (), KeyRef (id.bytes), cancellable);
              var ar = new Key [refs.length];
              for (int i = 0; i < ar.length; ++i) ar [i] = new Key.verbatim (refs [i].id.value);
              for (int i = 0; i < ar.length; ++i) if (refs [i].knowable) know (ar [i], refs [i]);
              return (owned) ar;
            }
          catch (GLib.Error e)
            {
              @catch (peer, (owned) e);
            }

          throw new PeerImplError.FAILED ("internal error");
        }

      protected override async Value find_value (Key peer, Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          for (int tries = 0; tries < 3; ++tries) try
            {
              var role = yield role_provider.lookup (peer, cancellable);
              var value = yield role.find_value (get_self (), KeyRef (id.bytes), cancellable);

              if (value.found)

                return new Kademlia.Value.inmediate (value.get_value ());
              else
                {
                  var ar = new Key [value.others.length];
                  for (int i = 0; i < ar.length; ++i) ar [i] = new Key.verbatim (value.others [i].id.value);
                  for (int i = 0; i < ar.length; ++i) if (value.others [i].knowable) know (ar [i], value.others [i]);
                  return new Kademlia.Value.delegated ((owned) ar);
                }
            }
          catch (GLib.Error e)
            {
              @catch (peer, (owned) e);
            }

          throw new PeerImplError.FAILED ("internal error");
        }

      private void know (Key peer, PeerRef? @ref)
        {
          if (Key.equal (id, peer) == false)
            {
              address_registry.add (peer, @ref.addresses);
              this.add_contact (peer);
            }
        }

      protected override async bool store_value (Key peer, Key key, GLib.Value? value = null, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          for (int tries = 0; tries < 3; ++tries) try
            {
              var role = yield role_provider.lookup (peer, cancellable);
              var result = yield role.store (get_self (), KeyRef (key.bytes), GValr.nat2net (value), cancellable);
              return result;
            }
          catch (GLib.Error e)
            {
              @catch (peer, (owned) e);
            }

          throw new PeerImplError.FAILED ("internal error");
        }

      protected override async bool ping_peer (Key peer, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          for (int tries = 0; tries < 3; ++tries) try
            {
              var role = yield role_provider.lookup (peer, cancellable);
              var result = yield role.ping (get_self (), cancellable);
              return result;
            }
          catch (GLib.Error e)
            {
              @catch (peer, (owned) e);
            }

          throw new PeerImplError.FAILED ("internal error");
        }
    }
}
