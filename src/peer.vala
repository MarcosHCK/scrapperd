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
  public class Peer : GLib.Object
    {
      public unowned Key id { get { return buckets.self; } }

      public const uint ALPHA = 3;

      private Buckets buckets;
      private ThreadPool<RpcCall> pool;

      public signal void added_contact (Key peer);
      public signal void staled_contact (Key peer);

      [Signal (run = "last" /* accumulator = first_wins */)]

      public async signal DelegatedValue? find_node (Key peer, Key key, ref GLib.Error? error)
        {
          GLib.Error.propagate (out error, new IOError.FAILED ("unimplemented"));
          return null;
        }

      [Signal (run = "last" /* accumulator = first_wins */)]

      public async signal bool ping (Key peer, ref GLib.Error? error)
        {
          GLib.Error.propagate (out error, new IOError.FAILED ("unimplemented"));
          return false;
        }

      construct
        {
          try
            {
              buckets = new Buckets (new Key.random ());
              pool = new ThreadPool<RpcCall>.with_owned_data (RpcCall.executor, (int) ALPHA, false);

              buckets.added_contact.connect ((peer) => this.added_contact (peer));
              buckets.staled_contact.connect ((peer) => this.staled_contact (peer));
            }
          catch (GLib.ThreadError e)
            {
              error (@"$(e.domain): $(e.code): $(e.message)");
            }
        }

      public async bool connect_to (Key to) throws GLib.Error
        {
          var sid1 = GLib.Signal.lookup ("find_node", typeof (Peer));
          var sid2 = GLib.Signal.lookup ("ping", typeof (Peer));
          var call1 = new RpcCall.failable (sid1, 2);

          buckets.insert (to);

          call1.nth_value (0).init (typeof (Key));
          call1.nth_value (0).set_boxed (to);
          call1.nth_value (1).init (typeof (Key));
          call1.nth_value (1).set_boxed (id);

          call1.instance.init_from_instance (this);
          call1.result.init (typeof (Kademlia.DelegatedValue));

          RpcCall.send (call1, pool);

          foreach (unowned var contact in ((DelegatedValue) Kademlia.Value.get_value (call1.result)).neighbors)
            {
              var call2 = new RpcCall.failable (sid2, 1);

              call2.nth_value (0).init (typeof (Key));
              call2.nth_value (0).set_boxed (contact);
              call2.instance.init_from_instance (this);
              call2.result.init (typeof (bool));
              RpcCall.send_no_reply (call2, pool);
            }
          return true;
        }
    }
}
