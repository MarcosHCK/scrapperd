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
      public signal void staled_contact (Key peer);

      protected async virtual KeyList find_node (Key peer, Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          throw new IOError.FAILED ("unimplemented");
        }

      protected async virtual bool ping_node (Key peer, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          throw new IOError.FAILED ("unimplemented");
        }

      construct
        {
          try
            {
              buckets.added_contact.connect ((peer) => this.added_contact (peer));
              buckets.staled_contact.connect ((peer) => this.staled_contact (peer));
            }
          catch (GLib.ThreadError e)
            {
              error (@"$(e.domain): $(e.code): $(e.message)");
            }
        }

      public Peer (Key? id = null)
        {
          Object (id : id);
        }

      public async bool check (Key[] peers, GLib.Cancellable? cancellable = null) throws GLib.Error

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

              check_nodes.begin (lists [p].data, cancellable, (o, res) =>
                {
                  try { ((Peer) o).check_nodes.end (res); } catch (GLib.Error e)
                    {
                      errors.push ((owned) e);
                    }

                  GLib.AtomicUint.set (ref dones [p], 1);
                });
            }

          for (unowned uint pending = 1; pending > 0;)
            {
              context.iteration (true);
              pending = 0;

              for (unowned uint i = 0; i < ALPHA; ++i)

                pending |= GLib.AtomicUint.get (ref dones [i]) ^ 1;
            }

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

      async bool check_node (Key peer, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          try { return yield ping_node (peer, cancellable); } catch (GLib.IOError e)
            {
              switch (e.code)
                {
                  case GLib.IOError.CONNECTION_CLOSED:
                  case GLib.IOError.CONNECTION_REFUSED:
                  case GLib.IOError.NETWORK_UNREACHABLE:
                  case GLib.IOError.TIMED_OUT:

                    buckets.drop (peer);
                    return false;

                  default:

                    throw (owned) e; 
                }
            }
        }

      async bool check_nodes (Key[] peers, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          foreach (unowned var peer in peers)
            {
              yield check_node (peer, cancellable);
            }

          return true;
        }

      public async bool connectto (Key to, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          buckets.insert (to);
          var peers = yield find_node (to, id, cancellable);
          return yield check (peers.keys, cancellable);
        }
    }
}
