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
  public class InsertValueCrawler : GLib.Object, BaseCrawler
    {
      private uint any;
      [CCode (array_length_cexpr = "K_PEER_ALPHA")]
      private uint dones [Peer.ALPHA];
      private AsyncQueue<GLib.Error> errors;
      [CCode (array_length_cexpr = "K_PEER_ALPHA")]
      private GenericArray<Key>? lists [Peer.ALPHA];
      private ValuePeer peer;
      private Key target_id;
      private ThreadPool<Delegated> worker;

      [Compact (opaque = false)] class Delegated
        {
          public GLib.Cancellable cancellable;
          public uint k;
          public GenericArray<Key> peers;
          public unowned InsertValueCrawler self;
          public unowned GLib.Value* value;

          public Delegated (GenericArray<Key> peers, uint k, InsertValueCrawler self, GLib.Value* value, GLib.Cancellable? cancellable = null)
            {
              this.cancellable = cancellable;
              this.k = k;
              this.peers = peers;
              this.self = self;
              this.value = value;
            }
        }

      public async InsertValueCrawler (ValuePeer peer, owned Key target_id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          this.any = 0;
          this.errors = new AsyncQueue<GLib.Error> ();
          this.peer = peer;
          this.target_id = (owned) target_id;

          var max_threads = (int) dones.length;
          var exclusive = (bool) false;
          this.worker = new ThreadPool<Delegated>.with_owned_data (worker_b, max_threads, exclusive);

          Key[] peers = yield peer.lookup_node (this.target_id, cancellable);
          uint reserve = (peers.length + dones.length - 1) / dones.length;

          for (int i = 0; i < dones.length; ++i)
            {
              dones [i] = 0;
              lists [i] = new GenericArray<Key> (reserve);
            }

          for (unowned uint i = 0, j = 0; j < peers.length; ++j, i = (i + 1) % dones.length)
            {
              lists [i].add (peers [j].copy ());
            }
        }

      public extern async bool crawl (GLib.Value? value, GLib.Cancellable? cancellable) throws GLib.Error;

      [CCode (cname = "k_insert_value_crawler_crawl")]

      public void crawl_ (GLib.Value* value, GLib.Cancellable? cancellable, GLib.AsyncReadyCallback callback)
        {
          var task = new GLib.Task (this, cancellable, callback);

          task.set_source_tag ((void*) crawl_);
          task.set_static_name ("crawl_async");
          task.set_task_data (value, null);
          task.run_in_thread ((t, s, d, c) => ((InsertValueCrawler) s).crawl_worker (t, d, c));
        }

      public bool crawl_finish (GLib.AsyncResult res) throws GLib.Error
        {
          ((GLib.Task) res).propagate_boolean ();
          return any > 0;
        }

      void crawl_worker (GLib.Task task, GLib.Value* value, GLib.Cancellable? cancellable)
        {
          for (unowned uint i = 0; i < dones.length; ++i) if (lists [i].length == 0)

            GLib.AtomicUint.set (ref dones [i], 1);
          else
            {
              var delegated = new Delegated (lists [i], i, this, value, cancellable);
              try { worker.add (((owned) delegated)); } catch (GLib.Error e) { };
            }

          for (unowned uint i, pending = 1; pending > 0;)
            {
              GLib.Thread.yield ();

              for (i = 0, pending = 0; i < dones.length; ++i)

                pending |= AtomicUint.get (ref dones [i]) ^ 1;
            }

          task.return_boolean (true);
        }

      void worker_a (uint k, GLib.AsyncResult res)
        {
          var result = false;

          try { result = peer.insert_on_nodes.end (res); } catch (GLib.Error e)
            {
              errors.push ((owned) e);
            }

          if (result)

            GLib.AtomicUint.inc (ref any);
            GLib.AtomicUint.set (ref dones [k], 1);
        }

      static void worker_b (owned Delegated delegated)
        {
          unowned var cancellable = delegated.cancellable;
          unowned var id = delegated.self.target_id;
          unowned var self = delegated.self;
          unowned var value = (GLib.Value?) delegated.value;
          unowned uint done = 0;

          self.peer.insert_on_nodes.begin ((owned) delegated.peers, id, value, cancellable, (o, res) =>
            {
              delegated.self.worker_a (delegated.k, res);
              AtomicUint.set (ref done, 1);
            });

          while (AtomicUint.get (ref done) == 0) GLib.Thread.yield ();
        }
    }
}
