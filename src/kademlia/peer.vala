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
  public errordomain PeerError
    {
      FAILED,
      NOT_FOUND,
      UNREACHABLE;

      public static extern GLib.Quark quark ();
    }

  public abstract class Peer : GLib.Object
    {
      public unowned Key id
        {
          get
            {
              return buckets.self;
            }
          construct
            {
              if (value != null)

                buckets = new Buckets (value.copy ());
              else
                buckets = new Buckets (new Key.random ());
            }
        }

      public const uint ALPHA = 3;

      protected Buckets? buckets = null;
      public signal void added_contact (Key peer);
      public signal void dropped_contact (Key peer);
      public signal void staled_contact (Key peer);

      construct
        {
          buckets.added_contact.connect ((peer) => this.added_contact (peer));
          buckets.dropped_contact.connect ((peer) => this.dropped_contact (peer));
          buckets.staled_contact.connect ((peer) => this.staled_contact (peer));
        }

      protected Peer (Key? id = null)
        {
          Object (id : id);
        }

      public void add_contact (Key peer)
        {
          lock (buckets) buckets.insert (peer);
        }

      protected void awake_range (Key peer)
        {
          lock (buckets) buckets.awake_range (peer);
        }

      public void drop_contact (Key peer)
        {
          lock (buckets) buckets.drop (peer);
        }

      public async bool check_dormat_ranges (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          GLib.List<Key> list;
          lock (buckets) list = buckets.enumerate_dormant_ranges ();

          foreach (unowned var range in list)

            yield lookup_node (range);

          return true;
        }

      public async bool check_stale_contacts (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          GLib.List<Key> list;
          lock (buckets) list = buckets.enumerate_stale_contacts ();

          foreach (unowned var contact in list)

            if (true == yield ping (contact))
            
              lock (buckets) buckets.insert (contact);

          return true;
        }

      protected async virtual Key[] find_peer (Key peer, Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          throw new IOError.FAILED ("unimplemented");
        }

      public async Key[] find_peer_complete (Key? from, Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          if (from != null) add_contact (from);

          var ni = (SList<Key>) nearest (id);
          var ar = (Key[]) new Key [ni.length ()];
          int i = 0;

          for (unowned var l = (SList<Key>) ni; l != null; l = l.next) ar [i++] = (owned) l.data;
          return (owned) ar;
        }

      public async bool join (Key to, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          lock (buckets) buckets.insert (to);
          return (yield lookup_node (this.id, cancellable)).length > 1;
        }

      public async Key[] lookup_node (Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var crawler = new LookupNodeCrawler (this, id.copy ());
          return yield crawler.crawl (cancellable);
        }

      internal async Key[]? lookup_node_a (owned Key peer, Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          Key[] result;
          bool same;

          try
            {
              if ((same = Key.equal (peer, this.id)) == false)

                result = yield find_peer (peer, id, cancellable);
              else
                result = yield find_peer_complete (null, id, cancellable);

              if (!same) awake_range (peer);
              return (owned) result;
            }
          catch (PeerError e)
            {
              if (unlikely (e.code != PeerError.UNREACHABLE))

                throw (owned) e;
              else
                {
                  if (!same) drop_contact (peer);
                  return null;
                }
            }
        }

      public virtual GLib.SList<Key> nearest (Key to)
        {
          GLib.SList<Key> list;

          lock (buckets) list = buckets.nearest (to);
          return (owned) list;
        }

      public async bool ping (Key peer, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          bool same;

          try
            {
              if ((same = Key.equal (peer, this.id)) == false)

                return yield ping_peer (peer, cancellable);
              else
                return yield ping_peer_complete (null, cancellable);
            }
          catch (PeerError e)
            {
              if (unlikely (e.code != PeerError.UNREACHABLE))

                throw (owned) e;
              else
                {
                  if (!same) drop_contact (peer);
                  return false;
                }
            }
        }

      protected async virtual bool ping_peer (Key peer, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          throw new IOError.FAILED ("unimplemented");
        }

      public async bool ping_peer_complete (Key? from, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          if (from != null) add_contact (from);
          return true;
        }
    }
}
