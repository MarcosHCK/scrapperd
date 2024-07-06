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
          var context = (GLib.MainContext) MainContext.ref_thread_default ();
          var dones = new uint [ALPHA];
          var errors = new GLib.AsyncQueue<GLib.Error> ();
          var good = new uint [1];
          var lists = new GenericArray<Key> [ALPHA];
          Key[] peers = yield lookup_node (id, cancellable);

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

              insert_on_nodes.begin (lists [i], id, value, cancellable, (o, res) =>
                {
                  var result = false;

                  try { result = ((ValuePeer) o).insert_on_nodes.end (res); } catch (GLib.Error e)
                    {
                      errors.push ((owned) e);
                    }

                  if (result)

                    GLib.AtomicUint.inc (ref good [0]);
                    GLib.AtomicUint.set (ref dones [p], 1);
                });
            }

          runner (context, dones);

          if (errors.length_unlocked () > 0)
            {
              var f = errors.pop_unlocked ();

              for (unowned uint i = 0; i < errors.length_unlocked (); ++i)
                {
                  var e = errors.pop_unlocked ();
                  critical (@"$(e.domain): $(e.code): $(e.message)");
                }

              throw (owned) f;
            }

          return good [0] > 0;
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

      async bool insert_on_nodes (GenericArray<Key> peers, Key id, GLib.Value? value = null, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          bool good = false;
          foreach (unowned var peer in peers) if (yield insert_on_node (peer, id, value, cancellable)) good = true;
          return good;
        }

      public async GLib.Value? lookup (Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var context = (MainContext) GLib.MainContext.ref_thread_default ();
          var dones = new uint [ALPHA];
          var errors = new GLib.AsyncQueue<GLib.Error> ();
          var left = (uint) 0;
          var peers = new GLib.Queue<Key> ();
          var seed = (SList<Key>) nearest (id);
          var sorter = (CompareDataFunc<Key>) create_sorter (id.copy ());
          var values = new GLib.Queue<Value> ();
          var visited = new GenericSet<Key> (Key.hash, Key.equal);
          var lvisited = GLib.Mutex ();

          for (unowned var link = (SList<Key>) seed; link != null; link = link.next)
            {
              peers.push_head ((owned) link.data);
            }

          peers.sort (sorter);

          while (values.length == 0 && (left = peers.length) > 0)
            {
              for (unowned var i = 0; i < ALPHA; ++i)
                {
                  AtomicUint.set (ref dones [i], 1);
                }

              for (unowned var i = 0; i < uint.min (left, ALPHA); ++i)
                {
                  unowned Key peer;
  
                  lvisited.lock ();
                  var k = i;
                  var p = peers.pop_head ();
                  peer = p;

                  visited.add ((owned) p);
                  lvisited.unlock ();

                  AtomicUint.set (ref dones [k], 0);

                  lookup_in_node.begin (peer, id, cancellable, (o, res) =>
                    {
                      Value? value = null;

                      try { value = ((ValuePeer) o).lookup_in_node.end (res); } catch (GLib.Error e)
                        {
                          errors.push ((owned) e);
                        }

                      if (likely (value != null))
                        {
                          lvisited.lock ();

                          if (value.is_inmediate)

                            values.push_tail ((owned) value);
                          else
                            {
                              foreach (unowned var other in value.keys) if (visited.contains (other) == false)

                                peers.insert_sorted (other.copy (), sorter);
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

          return values.length == 0 ? null : values.pop_head ().steal_value ();
        }

      async Value? lookup_in_node (Key peer, Key id, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          bool same;

          try
            {
              if ((same = Key.equal (peer, this.id)) == false)

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
                  case PeerError.UNREACHABLE: if (!same) drop_contact (peer); return null;
                  default: throw (owned) e;
                }
            }
        }
    }
}
