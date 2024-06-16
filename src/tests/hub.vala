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
using ScrapperD;

namespace Testing
{
  public static int main (string[] args)
    {
      GLib.Test.init (ref args, null);
      GLib.Test.add_func (TESTPATHROOT + "/Hub/connect", () => test_connect ());
      GLib.Test.add_func (TESTPATHROOT + "/Hub/new", () => test_new ());
      return GLib.Test.run ();
    }

  static void test_connect ()
    {
      var locks = new Locks ();

      new Thread<void> ("client thread", () =>
        {
          var o = new TestServerHub (locks);

            o.weak_ref (() => AtomicUint.set (ref locks.done_threads [0], 1));
            o.run_in_thread ();
        });

      new Thread<void> ("server thread", () =>
        {
          var o = new TestClientHub (locks);

            o.weak_ref (() => AtomicUint.set (ref locks.done_threads [1], 1));
            o.run_in_thread ();
        });

      AsyncTest.wait (locks.done_threads);
    }

  static void test_new ()
    {
      GLib.Test.message ("refs: %u", ((Object) new Hub ()).ref_count);
    }

  class Locks
    {
      public uint[] done_preparing_client = new uint [] { 0 };
      public uint[] done_preparing_server = new uint [] { 0 };
      public uint[] done_testing = new uint [] { 0 };
      public uint[] done_threads = new uint [] { 0, 0 };
    }

  class TestClientHub : AsyncTest
    {
      public const uint16 port = 33334;
      public Locks locks { get; construct; }

      public TestClientHub (Locks locks)
        {
          Object (locks : locks);
        }

      protected async override void test ()
        {
          var hub = new Hub (port);

          AtomicUint.set (ref locks.done_preparing_client [0], 1);
          wait (locks.done_preparing_server);

          try { yield hub.connect_to (@"localhost:$(TestServerHub.port)"); } catch (GLib.Error e)
            {
              assert_no_error (e);
            }

          try { yield hub.get_proxy<NodeRole> (new Kademlia.Key.from_data ("other".data), TestInstance.ROLE); } catch (GLib.Error e)
            {
              assert_error (e, Kademlia.PeerError.quark (), Kademlia.PeerError.UNREACHABLE);
            }

          Kademlia.Key key;
          NodeRole proxy;

          for (unowned var i = 0; i < 2; ++i)
            {
              try { proxy = yield hub.get_proxy<NodeRole> (key = new Kademlia.Key.from_data (TestInstance.PASS.data), TestInstance.ROLE); } catch (GLib.Error e)
                {
                  assert_no_error (e);
                  assert_not_reached ();
                }

              assert_true (Kademlia.Key.equal (key, new Kademlia.Key.verbatim (proxy.Id)));

              try { yield hub.forget (key); } catch (GLib.Error e)
                {
                  assert_no_error (e);
                }
            }

          try { yield hub.finish (); } catch (GLib.Error e)
            {
              assert_no_error (e);
            }

          AtomicUint.set (ref locks.done_testing [0], 1);
        }
    }

  class TestInstance : Instance
    {
      public const string PASS = "testing";
      public const string ROLE = "testing";

      public override string role { get { return ROLE; } }

      class NodeRoleSkeleton : GLib.Object, NodeRole
        {
          public override uint8[] Id { owned get { return new Kademlia.Key.from_data (PASS.data).bytes.copy (); } }
        }

      public override bool dbus_register (GLib.DBusConnection connection, string object_path, GLib.Cancellable? cancellable) throws GLib.Error
        {
          base.dbus_register (connection, object_path, cancellable);
          var id = connection.register_object<NodeRole> (@"$object_path/$role", new NodeRoleSkeleton ());
          connection.on_closed.connect ((c, a, b) => c.unregister_object (id));
          return true;
        }
    }

  class TestServerHub : AsyncTest
    {
      public const uint16 port = 33335;
      public Locks locks { get; construct; }

      public TestServerHub (Locks locks)
        {
          Object (locks : locks);
        }

      protected async override void test ()
        {
          var hub = new Hub (port);

          hub.add_instance (new TestInstance ());
          hub.begin ();

          AtomicUint.set (ref locks.done_preparing_server [0], 1);
          wait (locks.done_testing);

          try { yield hub.finish (); } catch (GLib.Error e)
            {
              assert_no_error (e);
            }
        }
    }
}
