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
using Kademlia;
using KademliaDBus;

namespace Testing
{
  const string APPID = "org.hck.ScrapperD.Stress";

  public sealed class Application : ScrapperD.Application
    {
      private PeerImpl storage_peer;

      public Application ()
        {
          base (APPID, GLib.ApplicationFlags.NON_UNIQUE);
        }

      public static int main (string[] argv)
        {
          GLib.Test.init (ref argv, null);
          GLib.Test.add_func (TESTPATHROOT + "/Stress", () =>
            {
              var argv2 = new string [] { "stress", "-p", (Hub.DEFAULT_PORT - 1).to_string () };
              assert_cmpint (0, GLib.CompareOperator.EQ, (new Application ()).run (argv2));
            });
          return GLib.Test.run ();
        }

      static GLib.Bytes random_bytes (int min = 10, int max = 100)
        {
          /*
           * Major bug here: if you do 'var ba = new uint8 [GLib.Random.int_range (min, max)];', in
           * C code it gets translated as 'g_new (guint8, g_random_int_range (min, max));', and then
           * calls again 'g_random_int_range' to initialize vector size. I don't need to state where
           * the bug is.
           *
           */

          var le = GLib.Random.int_range (min, max);
          var ba = new uint8 [le];

          for (var i = 0; i < ba.length; ++i)

            ba [i] = (uint8) GLib.Random.int_range (uint8.MIN, uint8.MAX);

          return new GLib.Bytes ((owned) ba);
        }

      protected async override bool command_line_async (GLib.ApplicationCommandLine cmdline, GLib.Cancellable? cancellable)
        {
          bool good;

          if (true == (good = yield base.command_line_async (cmdline, cancellable)))
            {

              try { yield hub.join (@"localhost:$(Hub.DEFAULT_PORT)", cancellable); } catch (GLib.Error e)
                {
                  assert_no_error (e);
                }

              for (uint i = 0; i < GLib.Random.int_range (10, 100); ++i)
                {
                  var bytes = random_bytes (10, 100);
                  var done = false;
                  var id = new Key.random ();

                  try { done = yield storage_peer.insert (id, bytes, cancellable); } catch (GLib.Error e)
                    {
                      assert_no_error (e);
                    }

                  assert_true (done);
                }

              release ();
            }

          return good;
        }

      protected override async bool register_on_hub_async () throws GLib.Error
        {
          hub.add_peer (storage_peer = new PeerImplProxy ("storage"));
          return true;
        }
    } 
}
