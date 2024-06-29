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

      protected async virtual Key[] find_peer (Key peer, Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          throw new IOError.FAILED ("unimplemented");
        }

      public async Key[] find_peer_complete (Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var ni = (SList<Key>) nearest (id);
          var ar = (Key[]) new Key [ni.length ()];
          int i = 0;

          foreach (unowned var n in ni) ar [i++] = n.copy ();
          return (owned) ar;
        }

      protected async virtual bool ping_peer (Key peer, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          throw new IOError.FAILED ("unimplemented");
        }

      public async bool ping_peer_complete (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          return true;
        }

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

      public void drop_contact (Key peer)
        {
          lock (buckets) buckets.drop (peer);
        }

      public async bool join (Key to, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          lock (buckets) buckets.insert (to);
          return (yield lookup_node (this.id, cancellable)).length > 1;
        }

      public async Key[] lookup_node (Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var context = (MainContext) GLib.MainContext.ref_thread_default ();
          var closest = new GenericArray<Key> (Buckets.MAXSPAN);
          var dones = new uint [ALPHA];
          var errors = new GLib.AsyncQueue<GLib.Error> ();
          var left = (int) 0;
          var lvisited = GLib.Mutex ();
          var peers = new GLib.Queue<Key> ();
          var seed = (SList<Key>) nearest (id);
          var visited = new GenericSet<Key> (Key.hash, Key.equal);

          CompareDataFunc<Key> sorter = (a, b) =>
            {
              return Key.distance (a, id) - Key.distance (b, id);
            };

          foreach (unowned var key in seed)
            {
              peers.push_head (key.copy ());
            }

          while ((left = (int) peers.length) > 0)
            {

              for (unowned uint i = 0; i < ALPHA; ++i)
                {
                  AtomicUint.set (ref dones [i], 1);
                }

              for (unowned uint i = 0; i < uint.min (left, ALPHA); ++i)
                {
                  unowned Key peer;

                  lvisited.lock ();
                  var k = i;
                  var p = peers.pop_head ();
                  peer = p;

                  visited.add ((owned) p);
                  lvisited.unlock ();

                  AtomicUint.set (ref dones [k], 0);

                  lookup_node_a.begin (peer, id, cancellable, (o, res) =>
                    {
                      Key[] newl;

                      try { newl = ((Peer) o).lookup_node_a.end (res); } catch (GLib.Error e)
                        {
                          errors.push ((owned) e);
                          AtomicUint.set (ref dones [k], 1);
                          return;
                        }

                      if (unlikely (newl != null))

                      foreach (unowned var key in newl)
                        {
                          lvisited.lock ();

                          if (closest.find_custom (key, Key.equal))

                            lvisited.unlock ();
                          else
                            {
                              closest.add (key.copy ());
                              closest.sort_with_data (sorter);

                              closest.length = int.min (closest.length, (int) Buckets.MAXSPAN);

                              if (visited.contains (key) == false)

                                peers.push_tail (key.copy ());

                              lvisited.unlock ();
                            }
                        }

                      AtomicUint.set (ref dones [k], 1);
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
            }
        return closest.steal ();
        }

      async Key[]? lookup_node_a (Key peer, Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          try
            {
              if (Key.equal (peer, this.id) == false)

                return yield find_peer (peer, id, cancellable);
              else
                {
                  var ni = nearest (id);
                  var ar = new Key [ni.length ()];
                  int i = 0;

                  foreach (unowned var n in ni) ar [i++] = n.copy ();
                  return (owned) ar;
                }
            }
          catch (PeerError e)
            {
              if (unlikely (e.code != PeerError.UNREACHABLE))

                throw (owned) e;
              else
                {
                  lock (buckets) buckets.drop (peer);
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
    }
}
