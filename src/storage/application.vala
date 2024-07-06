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

[CCode (cprefix = "ScrapperdStorage", lower_case_cprefix = "scrapperd_storage_")]

namespace ScrapperD.Storage
{
  const string APPID = "org.hck.ScrapperD.Storage";

  public sealed class Application : ScrapperD.Application
    {

      public Application ()
        {
          base (APPID, GLib.ApplicationFlags.NON_UNIQUE);
        }

      public static int main (string[] argv)
        {
          return (new Application ()).run (argv);
        }

      protected override async void register_peers () throws GLib.Error
        {
          hub.add_local_peer ("storage", new Kademlia.DBus.PeerImpl (new Store ()));
        }
    } 
}
