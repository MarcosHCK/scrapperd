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
  public sealed class LookupNodeCrawler : GLib.Object, BaseCrawler
    {
      private GenericArray<Key> closest;
      [CCode (array_length_cexpr = "K_PEER_ALPHA")]
      private uint dones [Peer.ALPHA];
      private AsyncQueue<GLib.Error> errors;
      private Peer peer;
      private AsyncQueue<Key> peers;
      private CompareDataFunc<Key> sorter;
      private Key target_id;
      private GenericSet<Key> visited;
      private ThreadPool<Delegated> worker;

      [Compact (opaque = false)] class Delegated
        {
          public GLib.Cancellable cancellable;
          public uint k;
          public Key peer;
          public unowned LookupNodeCrawler self;

          public Delegated (owned Key peer, uint k, LookupNodeCrawler self, GLib.Cancellable? cancellable = null)
            {
              this.cancellable = cancellable;
              this.k = k;
              this.peer = (owned) peer;
              this.self = self;
            }
        }

      public LookupNodeCrawler (Peer peer, owned Key target_id) throws GLib.Error
        {
          this.closest = new GenericArray<Key> (2 * Buckets.MAXSPAN);
          this.errors = new AsyncQueue<GLib.Error> ();
          this.peer = peer;
          this.peers = new AsyncQueue<Key> ();
          this.sorter = create_sorter (target_id.copy ());
          this.target_id = (owned) target_id;
          this.visited = new GenericSet<Key> (Key.hash, Key.equal);

          var max_threads = (int) dones.length;
          var exclusive = (bool) false;
          this.worker = new ThreadPool<Delegated>.with_owned_data (worker_b, max_threads, exclusive);

          var seed = (SList<Key>) peer.nearest (this.target_id);
          peers.lock ();

          for (unowned var link = (SList<Key>) seed; link != null; link = link.next)
            {
              peers.push_unlocked ((owned) link.data);
            }

          peers.unlock ();
        }

      public extern async Key[] crawl (GLib.Cancellable? cancellable) throws GLib.Error;

      [CCode (cname = "k_lookup_node_crawler_crawl")]

      public void crawl_ (GLib.Cancellable? cancellable, GLib.AsyncReadyCallback callback)
        {
          var task = new GLib.Task (this, cancellable, callback);

          task.set_source_tag ((void*) crawl_);
          task.set_static_name ("crawl_async");
          task.run_in_thread ((t, s, d, c) => ((LookupNodeCrawler) s).crawl_worker (t, c));
        }

      public Key[] crawl_finish (GLib.AsyncResult res) throws GLib.Error
        {
          ((GLib.Task) res).propagate_boolean ();
          return closest.steal ();
        }

      void crawl_worker (GLib.Task task, GLib.Cancellable? cancellable)
        {
          uint left;

          while ((left = (int) peers.length ()) > 0)
            {
              for (unowned uint i = 0; i < dones.length; ++i)
                {
                  dones [i] = 1;
                }

              for (unowned uint i = 0; i < uint.min (left, dones.length); ++i)
                {
                  AtomicUint.set (ref dones [i], 0);
                  var delegated = new Delegated (peers.pop (), i, this, cancellable);
                  try { worker.add (((owned) delegated)); } catch (GLib.Error e) { };
                }

              for (unowned uint i, pending = 1; pending > 0;)
                {
                  GLib.Thread.yield ();

                  for (i = 0, pending = 0; i < dones.length; ++i)

                    pending |= AtomicUint.get (ref dones [i]) ^ 1;
                }

              errors.lock ();

              if (errors.length_unlocked () == 0)

                errors.unlock ();
              else
                {
                  var f = errors.pop_unlocked ();

                  for (unowned var i = 0; i < errors.length_unlocked (); ++i)
                    {
                      var e = errors.pop_unlocked ();
                      warning ("%s: %u: %s", e.domain.to_string (), e.code, e.message);
                    }

                  task.return_error ((owned) f);
                  errors.unlock ();
                  return;
                }
            }

          task.return_boolean (true);
        }

      void worker_a (uint k, GLib.AsyncResult res)
        {
          Key[]? newl = null;

          try { newl = peer.lookup_node_a.end (res); } catch (GLib.Error e)
            {
              errors.push ((owned) e);
            }

          if (likely (newl != null)) lock (visited)
            {
              foreach (unowned var key in newl) if (closest.find_custom (key, Key.equal) == false)
                {
                  closest.add (key.copy ());
                }

              closest.sort_values_with_data (sorter);
              closest.length = int.min (closest.length, (int) Buckets.MAXSPAN);

              foreach (unowned var key in newl) if (closest.find_custom (key, Key.equal) && ! visited.contains (key))
                {
                  visited.add (key.copy ());
                  peers.push_sorted (key.copy (), sorter);
                }
            }

          AtomicUint.set (ref dones [k], 1);
        }

      static void worker_b (owned Delegated delegated)
        {
          unowned var cancellable = delegated.cancellable;
          unowned var id = delegated.self.target_id;
          unowned var self = delegated.self;
          unowned uint done = 0;

          self.peer.lookup_node_a.begin ((owned) delegated.peer, id, cancellable, (o, res) =>
            {
              delegated.self.worker_a (delegated.k, res);
              AtomicUint.set (ref done, 1);
            });

          while (AtomicUint.get (ref done) == 0) GLib.Thread.yield ();
        }
    }
}
