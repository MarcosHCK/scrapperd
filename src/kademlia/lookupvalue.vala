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
  public sealed class LookupValueCrawler : GLib.Object, BaseCrawler
    {
      private GenericArray<Key> closest;
      [CCode (array_length_cexpr = "K_PEER_ALPHA")]
      private uint dones [Peer.ALPHA];
      private AsyncQueue<GLib.Error> errors;
      private ValuePeer peer;
      private Queue<Key> peers;
      private CompareDataFunc<Key> sorter;
      private Key target_id;
      private AsyncQueue<Kademlia.Value> values;
      private GenericSet<Key> visited;
      private ThreadPool<Delegated?> worker;

      [Compact (opaque = false)] class Delegated
        {
          public GLib.Cancellable cancellable;
          public uint k;
          public Key peer;
          public unowned LookupValueCrawler self;

          public Delegated (owned Key peer, uint k, LookupValueCrawler self, GLib.Cancellable? cancellable = null)
            {
              this.cancellable = cancellable;
              this.k = k;
              this.peer = (owned) peer;
              this.self = self;
            }
        }

      public LookupValueCrawler (ValuePeer peer, owned Key target_id) throws GLib.Error
        {
          this.closest = new GenericArray<Key> (2 * Buckets.MAXSPAN);
          this.errors = new AsyncQueue<GLib.Error> ();
          this.peer = peer;
          this.peers = new Queue<Key> ();
          this.sorter = create_sorter (target_id.copy ());
          this.target_id = (owned) target_id;
          this.values = new AsyncQueue<Kademlia.Value> ();
          this.visited = new GenericSet<Key> (Key.hash, Key.equal);

          var max_threads = (int) dones.length;
          var exclusive = (bool) false;
          this.worker = new ThreadPool<Delegated>.with_owned_data (worker_b, max_threads, exclusive);

          var seed = (SList<Key>) peer.nearest (this.target_id);

          for (unowned var link = (SList<Key>) seed; link != null; link = link.next)
            {
              peers.push_head ((owned) link.data);
            }
        }

      public extern async GLib.Value? crawl (GLib.Cancellable? cancellable) throws GLib.Error;

      [CCode (cname = "k_lookup_value_crawler_crawl")]

      public void crawl_ (GLib.Cancellable? cancellable, GLib.AsyncReadyCallback callback)
        {
          var task = new GLib.Task (this, cancellable, callback);

          task.set_source_tag ((void*) crawl_);
          task.set_static_name ("crawl_async");
          task.run_in_thread ((t, s, d, c) => ((LookupValueCrawler) s).crawl_worker (t, c));
        }

      public GLib.Value? crawl_finish (GLib.AsyncResult res) throws GLib.Error
        {
          ((GLib.Task) res).propagate_boolean ();
          return values.try_pop ()?.steal_value ();
        }

      void crawl_worker (GLib.Task task, GLib.Cancellable? cancellable)
        {
          uint left = 0;

          while (values.length () == 0 && (left = (int) peers.length) > 0)
            {
              for (unowned uint i = 0; i < dones.length; ++i)
                {
                  dones [i] = 1;
                }

              for (unowned uint i = 0; i < uint.min (left, dones.length); ++i) lock (visited)
                {
                  AtomicUint.set (ref dones [i], 0);
                  var delegated = new Delegated (peers.pop_head (), i, this, cancellable);
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
          Value? value = null;

          try { value = peer.lookup_in_node.end (res); } catch (GLib.Error e)
            {
              errors.push ((owned) e);
            }

          if (likely (value != null))
            {
              if (value.is_inmediate)
                {
                  values.push ((owned) value);
                }
              else lock (visited) foreach (unowned var other in value.keys) if (visited.contains (other) == false)
                {
                  visited.add (other.copy ());
                  peers.insert_sorted (other.copy (), sorter);
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

          self.peer.lookup_in_node.begin ((owned) delegated.peer, id, cancellable, (o, res) =>
            {
              delegated.self.worker_a (delegated.k, res);
              AtomicUint.set (ref done, 1);
            });

          while (AtomicUint.get (ref done) == 0) GLib.Thread.yield ();
        }
    }
}
