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

      public const uint MAXBACKOFF = 5;
      public const uint MAXSPAN = 20;

      public signal void added_contact (Key peer);
      public signal void dropped_contact (Key peer);
      public signal void staled_contact (Key peer);

      public Buckets (owned Key self)
        {
          this.buckets = new GLib.List<Bucket?> ();
          this.self = (owned) self;
        }

      static int compare_key (Key a, Key b)
        {
          return Key.equal (a, b) ? 0 : 1;
        }

      static int compare_stale_contact (StaleContact? a, StaleContact? b)
        {
          return compare_key (a.key, (Key) (void*) b);
        }

      public void drop (Key key)
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
                      bucket.nodes.push_head (bucket.replacements.pop_head ());
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

      public bool insert (Key key)
        {
          unowned var bucket = search (key, true).data;
          unowned var done = false;

          if ((done = (bucket.nodes.length < MAXSPAN)) == false)

            bucket.replacements.push_head (key.copy ());
          else
            {
              bucket.nodes.push_head (key.copy ());
              added_contact (bucket.nodes.head.data);
            }
          return done;
        }

      public GLib.SList<Key> nearest (Key key)
        {
          var got = 0;
          var distance = Key.distance (self, key);
          var result = new GLib.SList<Key> ();

          unowned GLib.List<Key>? head = null;
          unowned GLib.List<Bucket?>? pivt = null;
          unowned GLib.List<Bucket?>? link = null;
          unowned int i;

          for (i = 0; i < KeyVal.BITLEN; ++i) if (distance.nth_bit (i) == 1)
            {
              if ((pivt = search_index (KeyVal.BITLEN - (i + 1), false)) != null)
                {
                  for (link = pivt; link != null && got < MAXSPAN; link = link.prev)
                  for (head = link.data.nodes.head; head != null && got < MAXSPAN; head = head.next)
                    {
                      result.prepend (head.data.copy ());
                      ++got;
                    }

                  break;
                }
            }

          if (got < MAXSPAN)
            {
              result.prepend (self.copy ());
              ++got;
            }

          for (link = pivt == null ? buckets : pivt.next; link != null && got < MAXSPAN; link = link.next)
          for (head = link.data.nodes.head; head != null && got < MAXSPAN; head = head.next)
            {
              result.prepend (head.data.copy ());
              ++got;
            }

          result.reverse ();

          return result;
        }

      private unowned GLib.List<Bucket?>? search (Key key, bool create = false)
        {
          var distance = Key.distance (self, key);

          for (unowned var i = 0; i < KeyVal.BITLEN; ++i) if (distance.nth_bit (i) == 1)
            {
              return search_index (KeyVal.BITLEN - (i + 1), create);
            }
          return null;
        }

      private unowned GLib.List<Bucket?>? search_index (uint index, bool create = false)
        {
          unowned GLib.List<Bucket?> link;
          unowned GLib.CompareFunc<Bucket?> cmp1 = (a, b) => int.from_pointer ((void*) b) - (int) a.index;
          unowned GLib.CompareFunc<Bucket?> cmp2 = (a, b) => (int) b.index - (int) a.index;
          unowned var data = index.to_pointer ();

          do
            {
              if ((link = buckets.find_custom ((Kademlia.Bucket?) data, cmp1)) != null)

                return link;
              else if (create == false) return null; else
                {
                  buckets.insert_sorted (Bucket (index), cmp2);
                  continue;
                }
            }
          while (true);
        }
    }
}
