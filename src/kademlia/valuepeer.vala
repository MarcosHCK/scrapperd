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

[CCode (cprefix = "K", lower_case_cprefix = "k_")]

namespace Kademlia
{
  public abstract class ValuePeer : Peer
    {
      public ValueStore value_store { get; construct; }

      protected ValuePeer (ValueStore value_store, Key? id = null)
        {
          Object (id : id, value_store : value_store);
        }

      protected virtual async Value find_value (Key peer, Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          throw new IOError.FAILED ("unimplemented");
        }

      public async Value find_value_complete (Key? from, Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          GLib.Value? value;
          if (from != null) add_contact (from);

          if ((value = yield value_store.lookup_value (id, cancellable)) != null)

            return new Value.inmediate ((owned) value);
          else
            {
              var ni = (SList<Key>) nearest (id);
              var ar = (Key[]) new Key [ni.length ()];
              int i = 0;

              foreach (unowned var n in ni) ar [i++] = n.copy ();
              return new Value.delegated ((owned) ar);
            }
        }

      protected virtual async bool store_value (Key peer, Key id, GLib.Value? value = null, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          throw new IOError.FAILED ("unimplemented");
        }

      public async bool store_value_complete (Key? from, Key id, GLib.Value? value = null, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          if (from != null) add_contact (from);
          yield value_store.insert_value (id, value, cancellable);
          return true;
        }

      public async bool insert (Key id, GLib.Value? value = null, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var crawler = yield new InsertValueCrawler (this, id.copy (), cancellable);
          return yield crawler.crawl (value, cancellable);
        }

      async bool insert_on_node (Key peer, Key id, GLib.Value? value = null, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          bool same;

          try
            {
              if ((same = Key.equal (peer, this.id)) == false)

                return yield store_value (peer, id, value, cancellable);
              else
                return yield value_store.insert_value (id, value, cancellable);
            }
          catch (PeerError e)
            {
              if (unlikely (e.code != PeerError.UNREACHABLE))

                throw (owned) e;
              else
                {
                  if (! same) drop_contact (peer);
                  return false;
                }
            }
        }

      internal async bool insert_on_nodes (GenericArray<Key> peers, Key id, GLib.Value? value = null, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          bool good = false;
          foreach (unowned var peer in peers) if (yield insert_on_node (peer, id, value, cancellable)) good = true;
          return good;
        }

      public async GLib.Value? lookup (Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var crawler = new LookupValueCrawler (this, id.copy ());
          return yield crawler.crawl (cancellable);
        }

      internal async Value? lookup_in_node (owned Key peer, Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          Value? result;
          bool same;

          try
            {
              if ((same = Key.equal (peer, this.id)) == false)

                result = yield find_value (peer, id, cancellable);
              else
                {
                  GLib.Value? value;

                  if ((value = yield value_store.lookup_value (id, cancellable)) == null)

                    result = null;
                  else
                    result = new Value.inmediate ((owned) value);
                }

              if (!same) awake_range (peer);
              return (owned) result;
            }
          catch (PeerError e)
            {
              switch (e.code)
                {
                  case PeerError.NOT_FOUND: return null;
                  case PeerError.UNREACHABLE: if (!same) drop_contact (peer); return null;
                  default: throw (owned) e;
                }
            }
        }
    }
}
