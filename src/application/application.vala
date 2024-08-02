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

[CCode (cprefix = "Scrapperd", lower_case_cprefix = "scrapperd_")]

namespace ScrapperD
{
  public abstract class Application : GLib.Application
    {
      private Advertise.Clock? adv_clock = null;
      private Advertise.Peeker? adv_peeker = null;
      private Advertise.Hub adv_hub;
      public Kademlia.DBus.NetworkHub hub { get; private construct; }

      construct
        {
          adv_hub = new Advertise.Hub ();
          hub = new Kademlia.DBus.NetworkHub ();

          adv_hub.ensure_protocol (typeof (Kademlia.Ad.Protocol));

          add_main_option ("address", 'a', 0, GLib.OptionArg.STRING_ARRAY, "Address of entry node", "ADDRESS");
          add_main_option ("advertise-interval", 0, 0, GLib.OptionArg.INT, "Advertise interval", "MILLISECONDS");
          add_main_option ("advertise-port", 0, 0, GLib.OptionArg.INT, "Advertise port", "PORT");
          add_main_option ("port", 'p', 0, GLib.OptionArg.INT, "Port where to listen for peer hails", "PORT");
          add_main_option ("public", 0, 0, GLib.OptionArg.STRING_ARRAY, "Public addresses to publish", "ADDRESS");
          add_main_option ("version", 'V', 0, GLib.OptionArg.NONE, "Print version", null);
        }

      protected Application (string application_id, GLib.ApplicationFlags flags)
        {
          Object (application_id : application_id, flags : flags | GLib.ApplicationFlags.HANDLES_COMMAND_LINE);
        }

      public override int command_line (GLib.ApplicationCommandLine cmdline)
        {
          hold ();

          command_line_async.begin (cmdline, null, (app, res) =>
            {
              ((Application) app).command_line_async.end (res);
              release ();
            });

          return base.command_line (cmdline);
        }

      protected virtual async bool command_line_async (GLib.ApplicationCommandLine cmdline, GLib.Cancellable? cancellable = null)
        {
          unowned var options = cmdline.get_options_dict ();
          unowned var good = true;

          while (true)
            {
              int option_i;
              string option_s;
              GLib.VariantIter iter;

              Advertise.Channel ipv4_channel;

              var addresses = new GLib.SList<string> ();
              var advertise_interval = (int) 5000 /* 5 seconds */;
              var advertise_port = (uint16) Advertise.Ipv4Channel.DEFAULT_PORT;
              var entries = new GLib.SList<string> ();
              var port = (uint16) Kademlia.DBus.NetworkHub.DEFAULT_PORT;

              if (options.lookup ("address", "as", out iter)) while (iter.next ("s", out option_s))
                {
                  entries.prepend ((owned) option_s);
                }

              if (options.lookup ("advertise-port", "i", out option_i))
                {
                  if (option_i >= uint16.MIN && option_i < uint16.MAX)

                    advertise_port = (uint16) option_i;
                  else
                    {
                      good = false;
                      cmdline.printerr ("invalid port %i\n", option_i);
                      cmdline.set_exit_status (1);
                      break;
                    }
                }

              if (options.lookup ("advertise-interval", "i", out option_i)) if (option_i >= 200)

                advertise_interval = option_i;
              else
                {
                  good = false;
                  cmdline.printerr ("interval too short: %i\n", option_i);
                  cmdline.set_exit_status (1);
                  break;
                }

              if (options.lookup ("port", "i", out option_i))
                {
                  if (option_i >= uint16.MIN && option_i < uint16.MAX)

                    port = (uint16) option_i;
                  else
                    {
                      good = false;
                      cmdline.printerr ("invalid port %i\n", option_i);
                      cmdline.set_exit_status (1);
                      break;
                    }
                }

              if (options.lookup ("public", "as", out iter)) while (iter.next ("s", out option_s))
                {
                  addresses.prepend ((owned) option_s);
                }

              try { yield hub.add_local_address ("localhost", port, cancellable); } catch (GLib.Error e)
                {
                  good = false;
                  cmdline.printerr ("can not listen on localhost: %s: %u: %s\n", e.domain.to_string (), e.code, e.message);
                  cmdline.set_exit_status (1);
                  break;
                }

              foreach (unowned var address in addresses) try { yield hub.add_local_address (address, port, cancellable); } catch (GLib.Error e)
                {
                  good = false;
                  cmdline.printerr ("can not listen on localhost: %s: %u: %s\n", e.domain.to_string (), e.code, e.message);
                  cmdline.set_exit_status (1);
                  break;
                }

              if (unlikely (good == false)) break;

              try { ipv4_channel = new Advertise.Ipv4Channel (advertise_port); } catch (GLib.Error e)
                {
                  good = false;
                  cmdline.printerr ("can not create advertising channel: %s: %u: %s\n", e.domain.to_string (), e.code, e.message);
                  cmdline.set_exit_status (1);
                  break;
                }

              try { yield register_peers (); } catch (GLib.Error e)
                {
                  good = false;
                  cmdline.printerr ("can not register peers: %s: %u: %s\n", e.domain.to_string (), e.code, e.message);
                  cmdline.set_exit_status (1);
                  break;
                }

              var default_port = Kademlia.DBus.NetworkHub.DEFAULT_PORT;

              foreach (unowned var host_and_port in entries) try { yield hub.join_at (host_and_port, default_port, null, cancellable); } catch (GLib.Error e)
                {
                  var address = host_and_port;
                  try { address = GLib.NetworkAddress.parse (host_and_port, default_port).to_string (); } catch (GLib.Error e) { }

                  good = false;
                  cmdline.printerr ("can not join to network (%s): %s: %u: %s\n", address, e.domain.to_string (), e.code, e.message);
                  cmdline.set_exit_status (1);
                  break;
                }

              if (unlikely (good == false)) break;

              unowned Kademlia.Key? local_key;
              unowned Kademlia.DBus.Hub.Local? local_var;
              var iter2 = HashTableIter<Kademlia.Key, Kademlia.DBus.Hub.Local?> (hub.locals);
              var ar = new GenericArray<Kademlia.DBus.Address?> ();

              foreach (unowned var address in hub.list_local_addresses ())
                {
                  ar.add (address);
                }

              while (iter2.next (out local_key, out local_var))
                {
                  unowned var id = local_key;
                  unowned var role = local_var.role;

                  debug ("advertising node %s:%s", role, id.to_string ());
                  adv_hub.add_protocol (new Kademlia.Ad.Protocol (id, role, ar));
                }

              hold ();
              hub.start ();

              adv_hub.add_channel (ipv4_channel);
              adv_clock = new Advertise.Clock (adv_hub, advertise_interval);
              adv_peeker = new Advertise.Peeker (adv_hub);

              adv_peeker.got_ad.connect (on_got_ad);
              break;
            }

          return good;
        }

      private void on_got_ad (Advertise.Ad ad)
        {
          foreach (unowned var proto in ad.protocols) if (proto.name == Kademlia.Ad.Protocol.PROTO_NAME)
            {
              on_got_kademlia_ad (ad, (Kademlia.Ad.Protocol) proto);
            }
        }

      private void on_got_kademlia_ad (Advertise.Ad ad, Kademlia.Ad.Protocol proto)

          requires (proto.addresses != null)
          requires (proto.role != null)
        {
          Kademlia.Ad.join.begin (hub, proto, null, (o, res) =>
            {
              try { Kademlia.Ad.join.end (res); } catch (GLib.Error e)
                {
                  unowned var code = e.code;
                  unowned var domain = e.domain.to_string ();
                  unowned var message = e.message.to_string ();

                  warning ("failed to handle ad: %s: %u: %s", domain, code, message);
                }
            });
        }

      protected virtual async void register_peers () throws GLib.Error { }

      public override void shutdown ()
        {
          adv_clock?.stop ();
          adv_peeker?.stop ();
          base.shutdown ();
        }

      public override int handle_local_options (GLib.VariantDict options)
        {
          if (options.contains ("version"))
            {
              print ("%s\n", Config.PACKAGE_VERSION);
              return 0;
            }

          return base.handle_local_options (options);
        }
    }
}
