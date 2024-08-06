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
using Advertise;

namespace Testing
{
  public static int main (string[] args)
    {
      GLib.Test.init (ref args, null);
      GLib.Test.add_func (TESTPATHROOT + "/Advertise/Hub/deserialize", () => (new TestDeserialize ()).run ());
      GLib.Test.add_func (TESTPATHROOT + "/Advertise/Hub/new", () => (new TestNew ()).run ());
      GLib.Test.add_func (TESTPATHROOT + "/Advertise/Hub/serialize", () => (new TestSerialize ()).run ());
      return GLib.Test.run ();
    }

  class DummyChannel : GLib.Object, Channel
    {
      private GLib.AsyncQueue<Bytes> ads;

      construct
        {
          ads = new GLib.AsyncQueue<Bytes> ();
        }

      public ChannelSource create_source (GLib.Cancellable? cancellable)
        {
          assert_not_reached ();
        }

      public async GenericArray<GLib.Bytes> recv (GLib.Cancellable? cancellable) throws GLib.Error
        {
          GLib.Bytes bytes;

          if ((bytes = ads.pop ()) == null)

            throw new IOError.WOULD_BLOCK ("would block");
          else
            {
              GenericArray<Bytes> ar;
              (ar = new GenericArray<Bytes> (1)).add ((owned) bytes);
              return (owned) ar;
            }
        }

      public async bool send (GLib.Bytes contents, GLib.Cancellable? cancellable) throws GLib.Error
        {
          ads.push (contents);
          return true;
        }
    }

  class DummyProtocol : Protocol
    {
      public override string name { get { return "testing"; } }
    }

  class TestDeserialize : AsyncTest
    {
      protected Hub hub = new Hub ();

      protected override async void test ()
        {
          Ad[] ads;
          Channel channel;
          Protocol proto;

          hub.name = "testing";
          hub.description = "testing hub";
          hub.add_protocol (proto = new DummyProtocol ());
          hub.add_channel (channel = new DummyChannel ());

          try { yield hub.advertise (); } catch (GLib.Error e)
            {
              assert_no_error (e);
              return;
            }

          try { ads = yield hub.peek (); } catch (GLib.Error e)
            {
              assert_no_error (e);
              return;
            }

          assert_cmpint (1, GLib.CompareOperator.EQ, ads.length);
          unowned var ad = (Ad) ads [0];

          assert_cmpstr (ad.description, GLib.CompareOperator.EQ, hub.description);
          assert_cmpstr (ad.name, GLib.CompareOperator.EQ, hub.name);
          assert_cmpint (1, GLib.CompareOperator.EQ, ad.protocols.length);
          assert_cmpstr (proto.name, GLib.CompareOperator.EQ, ad.protocols [0].name);
        }
    }

  class TestNew : SyncTest
    {
      protected override void test ()
        {
          if (new Hub () == null) error ("WTF?");
        }
    }

  class TestSerialize : AsyncTest
    {
      protected Hub hub = new Hub ();

      protected override async void test ()
        {

          try { yield hub.advertise (); } catch (GLib.Error e)
            {
              assert_no_error (e);
            }

          hub.name = "testing";
          hub.description = "testing hub";

          try { yield hub.advertise (); } catch (GLib.Error e)
            {
              assert_no_error (e);
            }

          hub.add_protocol (new DummyProtocol ());

          try { yield hub.advertise (); } catch (GLib.Error e)
            {
              assert_no_error (e);
            }

          hub.add_channel (new DummyChannel ());

          try { yield hub.advertise (); } catch (GLib.Error e)
            {
              assert_no_error (e);
            }
        }
    }
}
