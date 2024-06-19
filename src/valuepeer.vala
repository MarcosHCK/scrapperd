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

      private GenericSet<unowned Key> inserting;

      construct
        {
          inserting = new GenericSet<unowned Key> (GLib.str_hash, GLib.str_equal);
        }

      protected ValuePeer (ValueStore value_store, Key? id = null)
        {
          Object (id : id, value_store : value_store);
        }

      protected virtual async Value find_value (Key peer, Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          throw new IOError.FAILED ("unimplemented");
        }

      protected virtual async bool store_value (Key peer, Key id, GLib.Value? value = null, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          throw new IOError.FAILED ("unimplemented");
        }

      public async bool insert (Key id, GLib.Value? value = null, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          bool doing;
          lock (inserting) doing = inserting.contains (id);
          return doing ? true : yield insert_a (id, value, cancellable);
        }

      async bool insert_a (Key id, GLib.Value? value = null, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var context = (GLib.MainContext) MainContext.get_thread_default ();
          var dones = new uint [ALPHA];
          var errors = new GLib.AsyncQueue<GLib.Error> ();
          var lists = new GenericArray<Key> [ALPHA];
          var peers = nearest (id);

          lock (inserting) inserting.add (id);

          unowned var list = peers;
          unowned uint i, n_peers = peers.length ();

          for (i = 0; i < ALPHA; ++i)
            {
              dones [i] = 0;
              lists [i] = new GenericArray<Key> (1 + n_peers / 3);
            }

          for (i = 0, list = peers; list != null; list = list.next, i = (i + 1) % ALPHA)
            {
              lists [i].add (list.data.copy ());
            }

          for (i = 0; i < ALPHA; ++i) if (lists [i].length == 0)

            GLib.AtomicUint.set (ref dones [i], 1);
          else
            {
              var p = i;

              insert_on_nodes.begin (lists [i], id, value, cancellable, (o, res) =>
                {
                  try { ((ValuePeer) o).insert_on_nodes.end (res); } catch (GLib.Error e)
                    {
                      errors.push ((owned) e);
                    }

                  GLib.AtomicUint.set (ref dones [p], 1);
                });
            }

          runner (context, dones);
          lock (inserting) inserting.remove (id);

          if (errors.length_unlocked () > 0)
            {
              var f = errors.pop_unlocked ();

              for (i = 0; i < errors.length_unlocked (); ++i)
                {
                  var e = errors.pop_unlocked ();
                  critical (@"$(e.domain): $(e.code): $(e.message)");
                }

              throw (owned) f;
            }

          return true;
        }

      async bool insert_on_node (Key peer, Key id, GLib.Value? value = null, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          try
            {
              if (Key.equal (peer, this.id) == false)

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
                  drop_contact (peer);
                  return false;
                }
            }
        }

      async bool insert_on_nodes (GenericArray<Key> peers, Key id, GLib.Value? value = null, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          foreach (unowned var peer in peers) yield insert_on_node (peer, id, value, cancellable);
          return true;
        }

      public async GLib.Value? lookup (Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var context = (MainContext) GLib.MainContext.get_thread_default ();
          var dones = new uint [ALPHA];
          var errors = new GLib.AsyncQueue<GLib.Error> ();
          var left = (uint) 0;
          var peers = new GLib.AsyncQueue<unowned Key> ();
          var seed = (SList<Key>) nearest (id);
          var values = new GLib.AsyncQueue<Value> ();
          var visited = new GenericSet<Key> (Key.hash, Key.equal);
          var lvisited = GLib.Mutex ();

          foreach (unowned var key in seed)
            {
              Key id_ = key.copy ();

              peers.push (id_);
              visited.add ((owned) id_);
            }

          while (values.length_unlocked () == 0 && (left = peers.length_unlocked ()) > 0)
            {
              for (unowned var i = 0; i < ALPHA; ++i)
                {
                  AtomicUint.set (ref dones [i], 1);
                }

              for (unowned var i = 0; i < uint.min (left, ALPHA); ++i)
                {
                  lvisited.lock ();
                  unowned var p = peers.pop_unlocked ();
                  unowned var k = i;

                  lvisited.unlock ();
                  AtomicUint.set (ref dones [i], 0);

                  lookup_in_node.begin (p, id, cancellable, (o, res) =>
                    {
                      Value? value;

                      try { value = ((ValuePeer) o).lookup_in_node.end (res); } catch (GLib.Error e)
                        {
                          errors.push ((owned) e);
                          AtomicUint.set (ref dones [k], 1);
                          return;
                        }

                      if (value != null && value.is_inmediate)
                        {
                          values.push ((owned) value);
                        }
                      else if (value != null)
                        {
                          lvisited.lock ();

                          foreach (unowned var peer in value.keys) if (visited.contains (peer) == false)
                            {
                              Key id_ = peer.copy ();

                              peers.push (id_);
                              visited.add ((owned) id_);
                            }

                          lvisited.unlock ();
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

          if (values.length_unlocked () > 0)
            {
              var f = values.pop_unlocked ();
              return f.steal_value ();
            }

          return null;
        }

      async Value? lookup_in_node (Key peer, Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          try
            {
              if (Key.equal (peer, this.id) == false)

                return yield find_value (peer, id, cancellable);
              else
                {
                  GLib.Value? value;

                  if ((value = yield value_store.lookup_value (id, cancellable)) == null)

                    return null;
                  else
                    return new Value.inmediate ((owned) value);
                }
            }
          catch (PeerError e)
            {
              switch (e.code)
                {
                  case PeerError.NOT_FOUND: return null;
                  case PeerError.UNREACHABLE: drop_contact (peer); return null;
                  default: throw (owned) e;
                }
            }
        }
    }
}
