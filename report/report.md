# Requerimientos

### Requerimientos generales

- Compilador de C/C++ (preferiblemente Clang)
- Compilador de Vala
- gcrypt, glib, gobject, gio, soup3
- Gtk 4
- meson

### Preparando los requerimientos

```sh
apt install clang
apt install vala
api install libgcrypt20-dev
apt install libglib2.0-dev
apt install libgtk-4-dev
apt install libsoup-3.0-dev
apt install meson
```

# Ejecutando la aplicación

### Compilando

```sh
git clone https://github.com/MarcosHCK/scrapperd.git
mkdir scrapperd/builddir/
cd scrapperd/builddir/
meson setup ..
meson compile
```

### Ejecutando nodo de almacenamiento

```sh
src/storage/scrapperd-storage -p [<port>] -a [<entry node>]
```

### Ejecutando nodo de scrapper

```sh
src/scrapper/scrapperd-scrapper -p [<port>] -a [<entry node>]
```

### Ejecutando aplicación gráfica

```sh
src/viewer/scrapperd-viewer
```

o

```sh
src/viewer/scrapperd-viewer -a [<entry node>]
```
