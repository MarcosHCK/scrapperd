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

[CCode (cprefix = "Scrapping", lower_case_cprefix = "scrapping_")]

namespace Scrapping
{
  [CCode (array_length_pos = 1.1, array_length_type = "gsize", cheader_filename = "glib.h", cname = "g_variant_get_fixed_array", simple_generics = true, type = "gconstpointer")]

  static extern unowned T[] _g_variant_get_fixed_array<T> (GLib.Variant variant, size_t element_size = sizeof (T));

  [Compact (opaque = true)]

  public class Entry
    {
      public GLib.Variant @base { get; internal set; }
      public GLib.Variant headers { get; internal set; }
      public GLib.Variant html { get; internal set; }
      public GLib.Variant link { get; internal set; }

      private GLib.Bytes? _bytes;
      private GLib.Uri? _uri;

      public GLib.Bytes bytes { get {
        if (unlikely (_bytes == null))
          _bytes = new Bytes.static (_g_variant_get_fixed_array (html));
          return _bytes;
      } }
      public GLib.Uri uri { get {
        if (unlikely (_uri == null)) try {
          _uri = Scrapping.normal_uri (link.get_string ()); } catch (GLib.Error e) { error (@"$(e.domain): $(e.code): $(e.message)"); }
          return _uri;
      } }
    }

  public errordomain ContentsError
    {
      FAILED,
      INVALID_FORMAT;

      public static extern GLib.Quark quark ();
    }

  public class Contents : GLib.Object, GLib.Initable
    {
      const string array_stype = "a" + base_stype;
      const string base_stype = "(m" + html_stype + "s" + headers_stype + ")";
      const string headers_stype = "a{ss}";
      const string html_stype = "ay";
      internal static GLib.VariantType array_vtype = new GLib.VariantType (array_stype);
      internal static GLib.VariantType base_vtype = new GLib.VariantType (base_stype);
      internal static GLib.VariantType headers_vtype = new GLib.VariantType (headers_stype);
      public GLib.Variant array { get; construct; }
      private Entry[] entries;

      public Contents (GLib.Variant array) throws GLib.Error
        {
          Object (array : array);
          init ();
        }

      public Contents.from_bytes (GLib.Bytes bytes, bool trusted = false) throws GLib.Error
        {
          Object (array : new Variant.from_bytes (array_vtype, bytes, trusted));
          init ();
        }

      public bool contains (GLib.Uri uri)
        {
          foreach (unowned var entry in entries) {}
          return false;
        }

      public unowned Entry? get_nth (uint nth)
        {
          return entries [nth];
        }

      internal void increment (GLib.VariantBuilder builder)
        {
          foreach (unowned var entry in entries) builder.add_value (entry.base);
        }

      public bool init (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          unowned string format_string = array_stype;
          unowned bool copy_only = false;

          if (unlikely (!array.check_format_string (format_string, copy_only)))
            {
              unowned string stype = array.get_type_string ();
              throw new ContentsError.INVALID_FORMAT ("invalid format '%s'", stype);
            }

          var iter = new GLib.VariantIter (array);
          var entries = new Entry [iter.n_children ()];
          GLib.Variant? value;
          int i = 0;

          while ((value = iter.next_value ()) != null)
            {
              entries [i] = new Entry ();
              entries [i].base = value;
              entries [i].headers = value.get_child_value (2);
              entries [i].html = value.get_child_value (0);
              entries [i].link = value.get_child_value (1);
              ++i;
            }

          this.entries = (owned) entries;
          return true;
        }
    }

  [Compact (opaque = true)]

  public class ContentsBuilder : GLib.VariantBuilder
    {

      public ContentsBuilder ()
        {
          typeof (Contents).class_ref ();
          base (Contents.array_vtype);
        }

      public ContentsBuilder.incremental (Contents contents)
        {
          this ();
          merge (contents);
        }

      public unowned ContentsBuilder add_header (string name, string value)
        {
          add ("{ss}", name, value);
          return this;
        }

      public unowned ContentsBuilder add_html (GLib.Bytes? bytes)
        {
          if (bytes == null)
            {
              unowned VariantType child_type = VariantType.BYTESTRING;
              var value = new GLib.Variant.maybe (child_type, null);
              add_value (value);
            }
          else
            {
              unowned bool trusted = false;
              unowned VariantType type = GLib.VariantType.BYTESTRING;

              var child = new GLib.Variant.from_bytes (type, bytes, trusted);
              var value = new GLib.Variant.maybe (null, child);
              add_value (value);
            }
          return this;
        }

      public unowned ContentsBuilder add_link (GLib.Uri uri)
        {
          var str = uri.to_string ();
          var value = new GLib.Variant.take_string (str);
          add_value (value);
          return this;
        }

      public new unowned ContentsBuilder close ()
        {
          base.close ();
          return this;
        }

      public unowned ContentsBuilder merge (Contents contents)
        {
          contents.increment (this);
          return this;
        }

      public unowned ContentsBuilder open_headers ()
        {
          base.open (Contents.headers_vtype);
          return this;
        }

      public unowned ContentsBuilder open_entry ()
        {
          base.open (Contents.base_vtype);
          return this;
        }
    }
}
