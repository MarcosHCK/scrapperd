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
      GLib.Test.add_func (TESTPATHROOT + "/Peer/connect_to/with_good_handler", () => test_connect_to_with_good_handler (new Key.random ()));
      GLib.Test.add_func (TESTPATHROOT + "/Peer/connect_to/with_null_handler", () => test_connect_to_with_null_handler (new Key.random ()));
      GLib.Test.add_func (TESTPATHROOT + "/Peer/new", () => test_new ());
      return GLib.Test.run ();
    }

  static void test_connect_to_no_handler (Key to)
    {
      var peer = new Peer ();
      var tmperr = (GLib.Error?) null;

      var context = (GLib.MainContext) GLib.MainContext.default ();
      var loop = new GLib.MainLoop (context, false);

      peer.connect_to.begin (to, (o, res) =>
        {
          try { ((Peer) o).connect_to.end (res); } catch (GLib.Error e)
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
      var peer = new Peer ();
      var tmperr = (GLib.Error?) null;

      var context = (GLib.MainContext) GLib.MainContext.default ();
      var loop = new GLib.MainLoop (context, false);

      peer.find_node.connect ((peer, key, ref error) =>
        {
          return new DelegatedValue (new Key [] { key.copy () });
        });

      peer.ping.connect ((peer, ref error) =>
        {
          return true;
        });

      peer.connect_to.begin (to, (o, res) =>
        {
          try { ((Peer) o).connect_to.end (res); } catch (GLib.Error e)
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

  static void test_connect_to_with_null_handler (Key to)
    {
      var peer = new Peer ();
      var tmperr = (GLib.Error?) null;

      var context = (GLib.MainContext) GLib.MainContext.default ();
      var loop = new GLib.MainLoop (context, false);

      peer.find_node.connect ((peer, key, ref error) =>
        {
          GLib.Error.propagate (out error, new IOError.FAILED_HANDLED ("unimplemented2"));
          return null;
        });

      peer.connect_to.begin (to, (o, res) =>
        {
          try { ((Peer) o).connect_to.end (res); } catch (GLib.Error e)
            {
              tmperr = e.copy ();
            }
          finally
            {
              loop.quit ();
            }
        });

      loop.run ();

      assert_error (tmperr, IOError.quark (), IOError.FAILED_HANDLED);
      assert_cmpstr (tmperr.message, GLib.CompareOperator.EQ, "unimplemented2");
    }

  static void test_new ()
    {
      GLib.Test.message ("self: %s", (new Peer ()).id.to_string ());
    }
}
