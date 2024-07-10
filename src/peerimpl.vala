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
  public class PeerImpl : ValuePeer
    {
      private WeakRef _hub;
      public Hub hub { owned get { return (Hub) _hub.get (); } internal set { _hub.set (value); } }

      construct
        {
          added_contact.connect ((k) => debug ("added contact %s:(%s)", k.to_string (), id.to_string ()));
          dropped_contact.connect ((k) => debug ("dropped contact %s:(%s)", k.to_string (), id.to_string ()));
          staled_contact.connect ((k) => debug ("staled contact %s:(%s)", k.to_string (), id.to_string ()));
        }

      public PeerImpl (ValueStore value_store, Key? id = null)
        {
          base (value_store, id);
        }

      private void @catch (Key peer, owned GLib.Error? e) throws GLib.Error
        {
          if (e.domain == IOError.quark ()) catch_io (peer, (IOError?) (owned) e);
          else if (e.domain == NetworkError.quark ()) catch_network (peer, (NetworkError?) (owned) e);
          else throw (owned) e;
        }

      private void catch_io (Key peer, owned GLib.IOError? e) throws GLib.Error
        {
          switch (e.code)
            {
              case GLib.IOError.CLOSED:
              case GLib.IOError.CONNECTION_CLOSED:
              case GLib.IOError.TIMED_OUT:

                debug ("contact lost %s:(%s)", peer.to_string (), id.to_string ());
                hub.drop_role (peer);
                break;

              default: throw (owned) e;
            }
        }

      private void catch_network (Key peer, owned NetworkError? e) throws GLib.Error
        {
          switch (e.code)
            {
              case NetworkError.RESETTED_PEER:

                debug ("contact lost %s:(%s)", peer.to_string (), id.to_string ());
                hub.drop_role (peer);
                break;

              default: throw (owned) e;
            }
        }

      private void know (Hub hub, Key peer, PeerRef? @ref)
        {
          if (Key.equal (id, peer) == false)
            {
              hub.add_contact_addresses (peer, @ref.addresses);
              this.add_contact (peer);
            }
        }

      protected virtual PeerRef get_self ()
        {
          return PeerRef (id.bytes, hub.list_local_addresses ());
        }

      protected override async Key[] find_peer (Key peer, Key id, GLib.Cancellable? cancellable = null) throws GLib.Error requires (_hub.get () != null)
        {
          while (true) try
            {
              var hub = this.hub;
              var role = yield hub.lookup_role (peer, cancellable);
              var refs = yield role.find_node (get_self (), KeyRef (id.bytes), cancellable);
              var ar = new Key [refs.length];
              for (int i = 0; i < ar.length; ++i) ar [i] = new Key.verbatim (refs [i].id.value);
              for (int i = 0; i < ar.length; ++i) if (refs [i].knowable) know (hub, ar [i], refs [i]);
              return (owned) ar;
            }
          catch (GLib.Error e)
            {
              @catch (peer, (owned) e);
            }
        }

      protected override async Value find_value (Key peer, Key id, GLib.Cancellable? cancellable = null) throws GLib.Error requires (_hub.get () != null)
        {
          while (true) try
            {
              var hub = this.hub;
              var role = yield hub.lookup_role (peer, cancellable);
              var value = yield role.find_value (get_self (), KeyRef (id.bytes), cancellable);

              if (value.found)

                return new Kademlia.Value.inmediate (value.get_value ());
              else
                {
                  var ar = new Key [value.others.length];
                  for (int i = 0; i < ar.length; ++i) ar [i] = new Key.verbatim (value.others [i].id.value);
                  for (int i = 0; i < ar.length; ++i) if (value.others [i].knowable) know (hub, ar [i], value.others [i]);
                  return new Kademlia.Value.delegated ((owned) ar);
                }
            }
          catch (GLib.Error e)
            {
              @catch (peer, (owned) e);
            }
        }

      protected override async bool store_value (Key peer, Key key, GLib.Value? value = null, GLib.Cancellable? cancellable = null) throws GLib.Error requires (_hub.get () != null)
        {
          while (true) try
            {
              var role = yield hub.lookup_role (peer, cancellable);
              var result = yield role.store (get_self (), KeyRef (key.bytes), ValueRef.nat2net (value), cancellable);
              return result;
            }
          catch (GLib.Error e)
            {
              @catch (peer, (owned) e);
            }
        }

      protected override async bool ping_peer (Key peer, GLib.Cancellable? cancellable = null) throws GLib.Error requires (_hub.get () != null)
        {
          while (true) try
            {
              var role = yield hub.lookup_role (peer, cancellable);
              var result = yield role.ping (get_self (), cancellable);
              return result;
            }
          catch (GLib.Error e)
            {
              @catch (peer, (owned) e);
            }
        }
    }
}
