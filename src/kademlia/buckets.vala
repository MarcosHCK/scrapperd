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
  public class Buckets
    {
      public Key self { get; private owned set; }
      private GLib.List<Bucket?> buckets;

      [CCode (cheader_filename = "glib.h", cname = "G_USEC_PER_SEC")]

      public extern const int64 USEC_PER_SEC;

      public const int64 FIRSTSTALETIME = 3 * USEC_PER_SEC;
      public const uint MAXBACKOFF = 3;
      public const int64 MAXSLEEPTIME = 3 * USEC_PER_SEC;
      public const uint MAXSPAN = 20;

      public signal void added_contact (Key peer);
      public signal void dropped_contact (Key peer);
      public signal void staled_contact (Key peer);

      public Buckets (owned Key self)
        {
          this.buckets = new GLib.List<Bucket?> ();
          this.self = (owned) self;
        }

      public void awake_range (Key key)
        {
          unowned var bucket = (Bucket?) search (key, false)?.data;
          unowned var now = (int64) GLib.get_monotonic_time ();
          if (bucket != null) bucket.lastlookup = now;
        }

      static int compare_index (Bucket? a, Bucket? b) { return (int) b.index - (int) a.index; }
      static int compare_index2 (Kademlia.Bucket? a, Kademlia.Bucket? b) { return int.from_pointer ((void*) b) - (int) a.index; }
      static int compare_key (Key a, Key b) { return Key.equal (a, b) ? 0 : 1; }
      static int compare_stale_contact (StaleContact? a, StaleContact? b) { return compare_key (a.key, (Key) (void*) b); }

      public void drop (Key key) requires (Key.equal (key, self) == false)
        {
          unowned Kademlia.Bucket? bucket;
          unowned GLib.List<Key> link = null;
          unowned GLib.List<StaleContact?> link2 = null;

          if ((bucket = search (key, false)?.data) != null)
            {
              if ((link = bucket.nodes.find_custom (key, compare_key)) != null)
                {
                  var t = link.data.copy ();
                  bucket.nodes.delete_link (link);
                  bucket.stale.push_head (StaleContact (t));
                  staled_contact (bucket.stale.head.data.key);

                  if (bucket.replacements.length > 0)
                    {
                      bucket.nodes.push_tail (bucket.replacements.pop_head ());
                      added_contact (bucket.nodes.head.data);
                    }
                }
              else if ((link2 = bucket.stale.find_custom ((StaleContact?) (void*) key, compare_stale_contact)) != null)
                {
                  if (link2.data.drop_count < MAXBACKOFF)

                    ++link2.data.drop_count;
                  else
                    {
                      dropped_contact ((Key) link2.data.key);
                      bucket.stale.delete_link (link2);
                    }
                }
              else if ((link = bucket.replacements.find_custom (key, compare_key)) != null)
                {
                  bucket.replacements.delete_link (link);
                }
            }
        }

      public GLib.List<Key> enumerate_dormant_ranges ()
        {
          var list = new GLib.List<Key> ();
          var now = (int64) GLib.get_monotonic_time ();

          foreach (unowned var bucket in buckets) if (now - bucket.lastlookup > MAXSLEEPTIME)
            {
              if (bucket.nodes.length > 0)
                {
                  var l = (int32) bucket.nodes.length;
                  var n = (uint) GLib.Random.int_range (0, l);

                  list.append (bucket.nodes.head.nth (n).data.copy ());
                }
            }
          return (owned) list;
        }

      public GLib.List<Key> enumerate_stale_contacts ()
        {
          var list = new GLib.List<Key> ();
          var now = (int64) GLib.get_monotonic_time ();

          foreach (unowned var bucket in buckets) foreach (unowned var stale in bucket.stale.head)
            {
              if (now - stale.lastping > (FIRSTSTALETIME * (1 << stale.drop_count)))
                {
                  list.append (stale.key.copy ());
                  stale.lastping = now;
                }
            }
          return (owned) list;
        }

      public bool insert (Key key) requires (Key.equal (key, self) == false)
        {
          unowned var bucket = (Bucket?) search (key, true).data;
          unowned var item = (StaleContact?) (void*) key;

          if (queue_bring_front<StaleContact?> (bucket.stale, item, compare_stale_contact))
            {
              bucket.stale.pop_head ();
              return insert (key);
            }
          else if (queue_bring_front<Key> (bucket.replacements, key, compare_key) == false)
            {
              if (queue_bring_front<Key> (bucket.nodes, key, compare_key))

                return false;
              if (bucket.nodes.length >= MAXSPAN)
                {
                  bucket.replacements.push_head (key.copy ());
                  return false;
                }
              else
                {
                  bucket.nodes.push_head (key.copy ());
                  added_contact (bucket.nodes.head.data);
                  return true;
                }
            }
          return false;
        }

      public GLib.SList<Key> nearest (Key key)
        {
          var got = 0;
          var result = new GLib.SList<Key> ();

          unowned GLib.List<Key>? head = null;
          unowned GLib.List<Bucket?>? pivt = null;
          unowned int i, j, d;

          if ((d = Key.distance (self, key)) < 0)
            {
              result.prepend (self.copy ());
              ++got;
            }

          for (j = 1 + (i = d < 0 ? 0 : d); got < MAXSPAN && (i >= 0 || j < Key.BITLEN); --i, ++j)
            {
              if (i >= 0)
              if ((pivt = search_index (i, false)) != null)
              for (head = pivt.data.nodes.head; head != null && got < MAXSPAN; head = head.next)
                {
                  result.prepend (head.data.copy ());
                  ++got;
                }

              if (got >= MAXSPAN) break;

              if (j < Key.BITLEN)
              if ((pivt = search_index (j, false)) != null)
              for (head = pivt.data.nodes.head; head != null && got < MAXSPAN; head = head.next)
                {
                  result.prepend (head.data.copy ());
                  ++got;
                }
            }

          if (got < MAXSPAN && d >= 0)
            {
              result.prepend (self.copy ());
              ++got;
            }

          result.reverse ();

          return result;
        }

      private unowned GLib.List<Bucket?>? search (Key key, bool create = false)
        {
          return search_index (Key.distance (self, key), create);
        }

      private unowned GLib.List<Bucket?>? search_index (int index, bool create = false) requires (index >= 0)
        {
          unowned GLib.List<Bucket?> link;
          unowned var data = index.to_pointer ();

          do
            {
              if ((link = buckets.find_custom ((Kademlia.Bucket?) data, compare_index2)) != null)

                return link;
              else if (create == false) return null; else
                {
                  buckets.insert_sorted (Bucket (index), compare_index);
                  continue;
                }
            }
          while (true);
        }
    }
}
