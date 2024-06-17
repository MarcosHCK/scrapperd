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

      protected async virtual Key[] find_peer (Key peer, Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          throw new IOError.FAILED ("unimplemented");
        }

      protected async virtual bool ping_peer (Key peer, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          throw new IOError.FAILED ("unimplemented");
        }

      construct
        {
          try
            {
              buckets.added_contact.connect ((peer) => this.added_contact (peer));
              buckets.dropped_contact.connect ((peer) => this.dropped_contact (peer));
              buckets.staled_contact.connect ((peer) => this.staled_contact (peer));
            }
          catch (GLib.ThreadError e)
            {
              error (@"$(e.domain): $(e.code): $(e.message)");
            }
        }

      protected Peer (Key? id = null)
        {
          Object (id : id);
        }

      public void add_contact (Key peer)
        {
          lock (buckets) buckets.insert (peer);
        }

      public void drop_contact (Key peer)
        {
          lock (buckets) buckets.drop (peer);
        }

      public async bool join (Key to, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          lock (buckets) buckets.insert (to);
          var peers = yield find_peer (to, id, cancellable);
          return yield notify_join (peers, cancellable);
        }

      public GLib.SList<Key> nearest (Key to)
        {
          GLib.SList<Key> list;

          lock (buckets) list = buckets.nearest (to);
          return (owned) list;
        }

      async bool notify_join (Key[] peers, GLib.Cancellable? cancellable = null) throws GLib.Error

          requires (peers.length > 0)
        {
          var context = (GLib.MainContext) MainContext.get_thread_default ();
          var dones = new uint [ALPHA];
          var errors = new GLib.AsyncQueue<GLib.Error> ();
          var lists = new GenericArray<Key> [ALPHA];

          for (unowned uint i = 0; i < ALPHA; ++i)
            {
              dones [i] = 0;
              lists [i] = new GenericArray<Key> (1 + peers.length / 3);
            }

          for (unowned uint i = 0, j = 0; j < peers.length; ++j, i = (i + 1) % ALPHA)
            {
              lists [i].add (peers [j].copy ());
            }

          for (unowned uint i = 0; i < ALPHA; ++i) if (lists [i].length == 0)

            GLib.AtomicUint.set (ref dones [i], 1);
          else
            {
              var p = i;

              notify_nodes.begin (lists [p].data, cancellable, (o, res) =>
                {
                  try { ((Peer) o).notify_nodes.end (res); } catch (GLib.Error e)
                    {
                      errors.push ((owned) e);
                    }

                  GLib.AtomicUint.set (ref dones [p], 1);
                });
            }

          runner (context, dones);

          if (errors.length_unlocked () > 0)
            {
              var f = errors.pop_unlocked ();

              for (unowned var i = 0; i < errors.length_unlocked (); ++i)
                {
                  var e = errors.pop_unlocked ();
                  critical (@"$(e.domain): $(e.code): $(e.message)");
                }

              throw (owned) f;
            }

          return true;
        }

      async bool notify_node (Key peer, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          try { return yield ping_peer (peer, cancellable); } catch (PeerError e)
            {
              if (unlikely (e.code != PeerError.UNREACHABLE))

                throw (owned) e;
              else
                {
                  lock (buckets) buckets.drop (peer);
                  return false;
                }
            }
        }

      async bool notify_nodes (Key[] peers, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          foreach (unowned var peer in peers)
            {
              if (Key.equal (peer, this.id) == false)

                yield notify_node (peer, cancellable);
            }

          return true;
        }
    }
}
