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
  [Compact (opaque = false)]
  [CCode (cheader_filename = "rpccall.h", copy_function = "k_rpc_call_ref", free_function = "k_rpc_call_unref")]

  public class RpcCall
    {
      public uint signal_id;
      public uint n_values;
      public uint done { get; }

      public GLib.Value result;
      public GLib.Value instance;
      public GLib.Value first;

      public RpcCall (uint signal_id, uint n_values = 0);
      public RpcCall.failable (uint signal_id, uint n_values = 0);

      public unowned GLib.Value* nth_value (uint nth);

      public static void executor (owned RpcCall call);
      public static bool send (RpcCall call, GLib.ThreadPool<RpcCall> pool) throws GLib.Error;
      public static async bool send_async (RpcCall call, GLib.ThreadPool<RpcCall> pool) throws GLib.Error;
      public static void send_no_reply (RpcCall call, GLib.ThreadPool<RpcCall> pool);
    }
}
