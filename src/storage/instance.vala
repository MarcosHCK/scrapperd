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
  public class StorageInstance : Instance
    {
      private HashTable<void*, NodeIds?> nodes;
      private Peer peer;

      public override string role { get { return ROLE; } }

      struct NodeIds
        {
          public uint iface_id;
          public uint nrole_id;

          public NodeIds (uint iface_id, uint nrole_id)
            {
              this.iface_id = iface_id;
              this.nrole_id = nrole_id;
            }
        }

      class NodeRoleSkeleton : GLib.Object, NodeRole
        {
          public NodeRoleSkeleton (Peer peer)
            {
              Object (peer : peer);
            }

          public Peer peer { get; construct; }
          public override uint8[] Id { owned get { return peer.id.bytes.copy (); } }
        }

      construct
        {
          nodes = new HashTable<void*, NodeIds?> (GLib.direct_hash, GLib.direct_equal);
          peer = new Peer (hub);
        }

      [ModuleInit]
      [CCode (cname = "g_io_storagemod_load")] public static void load (GLib.IOModule module)
        {
          module.set_name (ROLE);
          Instance.install<StorageInstance> (ROLE, ">=" + Config.PACKAGE_VERSION);
        }

      [CCode (cname = "g_io_storagemod_query")] public static string[] query ()
        {
          var extension_points = new string[] { Instance.EXTENSION_POINT };
          return extension_points;
        }

      [CCode (cname = "g_io_storagemod_unload")] public static void unload (GLib.IOModule module)
        {
        }

      public override bool dbus_register (GLib.DBusConnection connection, string object_path, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          base.dbus_register (connection, object_path, cancellable);
          unowned var id1 = connection.register_object<ValueNode> (@"$object_path/$role", new ValueNodeSkeleton (hub, peer));
          unowned var id2 = connection.register_object<NodeRole> (@"$object_path/$role", new NodeRoleSkeleton (peer));

          lock (nodes) nodes.insert (connection, NodeIds (id1, id2));
          return true;
        }

      public override void dbus_unregister (GLib.DBusConnection connection)
        {
          base.dbus_unregister (connection);
          unowned var id = (NodeIds?) null;

          lock (nodes) id = nodes.lookup (connection);
          connection.unregister_object (id.iface_id);
          connection.unregister_object (id.nrole_id);
        }

      public override bool join (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          var known = hub.get_known_peers ();

          join_async.begin ((owned) known, cancellable, (o, res) =>
            {
              ((StorageInstance) o).join_async.end (res);
            });
          return true;
        }

      public async bool join_async (owned Kademlia.Key[] keys, GLib.Cancellable? cancellable = null)
        {
          foreach (unowned var key in keys) try { yield peer.join (key, cancellable); } catch (GLib.Error e)
            {
              critical (@"$(e.domain): $(e.code): $(e.message)");
            }
          return true;
        }
    }
}
