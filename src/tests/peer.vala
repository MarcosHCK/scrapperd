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
  public static int main (string[] args)
    {
      GLib.Test.init (ref args, null);
      GLib.Test.add_func (TESTPATHROOT + "/Peer/connect_to/no_handler", () => test_connect_to_no_handler (new Key.random ()));
      GLib.Test.add_func (TESTPATHROOT + "/Peer/connect_to/with_good_find_handler", () => test_connect_to_with_good_find_handler (new Key.random ()));
      GLib.Test.add_func (TESTPATHROOT + "/Peer/connect_to/with_good_handler", () => test_connect_to_with_good_handler (new Key.random ()));
      GLib.Test.add_func (TESTPATHROOT + "/Peer/new", () => test_new ());
      return GLib.Test.run ();
    }

  class TestPeerFindHandle : Peer
    {

      protected async override KeyList find_node (Key peer, Key id, GLib.Cancellable? cancellable) throws GLib.Error
        {
          return new KeyList (new Key [] { id.copy () });
        }
    }

  class TestPeerPingHandle : Peer
    {

      protected async override bool ping_node (Key peer, GLib.Cancellable? cancellable) throws GLib.Error
        {
          return true;
        }
    }

  class TestPeerAllHandle : Peer
    {

      protected async override KeyList find_node (Key peer, Key id, GLib.Cancellable? cancellable) throws GLib.Error
        {
          GLib.Test.message ("find_node (%s, %s)", peer.to_string (), id.to_string ());
          return new KeyList (new Key [] { id.copy () });
        }

      protected async override bool ping_node (Key peer, GLib.Cancellable? cancellable) throws GLib.Error
        {
          GLib.Test.message ("ping_node (%s)", peer.to_string ());
          return true;
        }
    }

  static void test_connect_to_no_handler (Key to)
    {
      var peer = new Peer ();
      var tmperr = (GLib.Error?) null;

      var context = (GLib.MainContext) GLib.MainContext.default ();
      var loop = new GLib.MainLoop (context, false);

      peer.connectto.begin (to, null, (o, res) =>
        {
          try { ((Peer) o).connectto.end (res); } catch (GLib.Error e)
            {
              tmperr = e.copy ();
            }
          finally
            {
              loop.quit ();
            }
        });

      loop.run ();

      assert_error (tmperr, IOError.quark (), IOError.FAILED);
      assert_cmpstr (tmperr.message, GLib.CompareOperator.EQ, "unimplemented");
    }

  static void test_connect_to_with_good_find_handler (Key to)
    {
      var context = (GLib.MainContext) GLib.MainContext.default ();
      var loop = new GLib.MainLoop (context, false);
      var tmperr = (GLib.Error?) null;

      var peer = new TestPeerFindHandle ();

      peer.connectto.begin (to, null, (o, res) =>
        {
          try { ((Peer) o).connectto.end (res); } catch (GLib.Error e)
            {
              tmperr = e.copy ();
            }
          finally
            {
              loop.quit ();
            }
        });

      loop.run ();

      assert_error (tmperr, IOError.quark (), IOError.FAILED);
      assert_cmpstr (tmperr.message, GLib.CompareOperator.EQ, "unimplemented");
    }

  static void test_connect_to_with_good_handler (Key to)
    {
      var context = (GLib.MainContext) GLib.MainContext.default ();
      var loop = new GLib.MainLoop (context, false);
      var tmperr = (GLib.Error?) null;

      var peer = new TestPeerAllHandle ();

      peer.connectto.begin (to, null, (o, res) =>
        {
          try { ((Peer) o).connectto.end (res); } catch (GLib.Error e)
            {
              tmperr = e.copy ();
            }
          finally
            {
              loop.quit ();
            }
        });

      loop.run ();

      assert_no_error (tmperr);
    }

  static void test_new ()
    {
      GLib.Test.message ("self: %s", (new Peer ()).id.to_string ());
    }
}
