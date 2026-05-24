# Bazel Build Overview

This repository contains an experimental Bazel build for darktable. The current
scope is Linux only. The build is designed to move toward a mostly hermetic
Bzlmod-based build while keeping the GTK desktop stack as the explicit system
boundary. Future macOS support should reuse the same structure, but will need a
separate platform configuration and replacement rules for Linux-specific
libraries and linker flags.

## Entry Points

Use Bazelisk, or a `bazel` launcher backed by Bazelisk. The repository pins the
Bazel version in `.bazelversion`.

```sh
bazel build --config=linux //src:bazel_build_milestone
```

The current milestone target builds:

- `//src:darktable`
- `//src:darktable-cli`
- `//src:darktable-cltest`
- `//src:darktable-generate-cache`
- `//src:libdarktable.so`
- `//src:bazel_plugin_milestone`
- `//src:bazel_runtime_tree`

The plugin milestone builds the currently modeled Linux plugin shared
libraries:

```sh
bazel build --config=linux //src:bazel_plugin_milestone
```

This target includes IOP, view, lighttable, image I/O format, and image I/O
storage plugins as `lib*.so` artifacts.

To arrange those shared libraries in the same directory structure darktable's
runtime loader expects, build:

```sh
bazel build --config=linux //src:bazel_plugin_runtime_layout
```

This produces:

- `bazel-bin/src/bazel-runtime/lib/darktable/views`
- `bazel-bin/src/bazel-runtime/lib/darktable/plugins`
- `bazel-bin/src/bazel-runtime/lib/darktable/plugins/lighttable`
- `bazel-bin/src/bazel-runtime/lib/darktable/plugins/imageio/format`
- `bazel-bin/src/bazel-runtime/lib/darktable/plugins/imageio/storage`

For a fuller runnable tree, build:

```sh
bazel build --config=linux //src:bazel_runtime_tree
```

This produces `bazel-bin/src/darktable-runtime`, with:

- `bin/` containing `darktable`, `darktable-cli`, `darktable-cltest`,
  `darktable-generate-cache`, and a `darktable-bazel` launcher.
- `lib/darktable/` containing `libdarktable.so`, views, IOP plugins,
  lighttable plugins, and image I/O plugins.
- `share/darktable/` containing runtime data, generated `darktablerc`,
  generated `darktableconfig.xml`, RawSpeed camera data, Lua scripts, OpenCL
  kernels, styles, themes, watermarks, pixmaps, and helper scripts.
- Minimal unlocalized desktop/appstream metadata under `share/applications`
  and `share/metainfo`.
- An empty `share/locale` directory so binaries can resolve their configured
  locale path even before translation catalogs are modeled.

The launcher in the runtime tree passes `--moduledir`, `--datadir`, and
`--localedir`. When packaged ICU data is present, it also exports `ICU_DATA` to
`share/darktable/icu`:

```sh
bazel-bin/src/darktable-runtime/bin/darktable-bazel --version
```

The runtime tree also has a non-GUI smoke test:

```sh
bazel test --config=linux //src:bazel_runtime_smoke_test
```

This test validates representative runtime files, plugin directories, and early
`--version` paths for the launcher and CLI-style binaries without requiring an
X11 or Wayland session.

SQLite ICU integration has a narrower smoke test:

```sh
bazel test --config=linux //src:bazel_sqliteicu_smoke_test
```

That test points `ICU_DATA` at the generated runtime tree, opens an in-memory
SQLite database, registers `src/common/sqliteicu.c`, and verifies that
`icu_load_collation` can create an ICU-backed collation.

`//src:darktable-bazel` also emits `bazel-bin/src/darktable-bazel`, a small
wrapper that forwards to the launcher inside the runtime tree.

For a cache-busting sandbox verification run, use an otherwise harmless extra
compile define:

```sh
bazel build --config=linux --copt=-DDT_BAZEL_SANDBOX_VERIFY //src:bazel_build_milestone
```

## Configuration

The root `.bazelrc` enables Bzlmod and sets common C/C++ defaults:

- C++ defaults to C++20. RawSpeed uses C++20 language features, so the whole
  repository is compiled as C++20 rather than carrying a target-local override.
- C defaults to C99.
- `HAVE_CONFIG_H`, `_XOPEN_SOURCE=700`, and PIC are applied globally.
- The Linux configuration enables the feature macros needed by the current
  milestone: OpenCL, LibRaw, Lua, GPhoto2, GraphicsMagick, JPEG XL, WebP, AVIF,
  HEIF, OpenEXR, OpenJPEG, ICU, and OpenMP.

The `linux_full` configuration exists as a placeholder for fuller desktop
feature coverage. It currently adds macros for map, colord-gtk, libsecret,
GMIC, and print support, but those features are not fully modeled as Bazel
targets yet.

The Linux configuration mounts `/usr/include` and `/usr/lib/x86_64-linux-gnu`
into the sandbox. This is required while the transitional `pkg-config` rules
refer to host system headers and libraries.

## Bzlmod Layout

`MODULE.bazel` is the top-level dependency declaration. It uses:

- `rules_cc` for C/C++ rules.
- `rules_pkg` for future packaging work.
- `rules_shell` for shell smoke tests.
- Bazel Central Registry modules for migrated leaf libraries: `zlib`,
  `sqlite3`, `pugixml`, `brotli`, `curl`, `highway`, `libpng`,
  `libjpeg_turbo`, `libxml2`, `libwebp`, `libtiff`, `libavif`, `libheif`,
  `imath`, `openexr`, `skcms`, and `icu`.
- `http_archive`, declared through Bzlmod `use_repo_rule`, for pinned upstream
  release archives that are not available as usable BCR modules yet.
- `new_local_repository` for vendored source trees already present in the
  darktable source checkout.
- `pkg_config_repository`, a custom repository rule in
  `bazel/pkg_config.bzl`, for transitional system dependencies.

Vendored local repositories currently modeled through `new_local_repository`
are:

- `@whereami`
- `@libxcf`
- `@lua_internal`
- `@lautoc`
- `@libraw_internal`
- `@rawspeed`

These repositories have Bazel BUILD files under `bazel/third_party/`.

Root-owned aliases for migrated leaf dependencies live under `third_party/`.
Source targets should depend on those aliases rather than directly on external
repository labels. This keeps labels stable if a provider changes, for example
using `//third_party/jpeg:jpeg` even though the current provider is
`@libjpeg_turbo//:jpeg`.

The current aliases are:

- `//third_party/avif:avif`
- `//third_party/curl:curl`
- `//third_party/heif:heif`
- `//third_party/icu:icu`
- `//third_party/imath:imath`
- `//third_party/jpeg:jpeg`
- `//third_party/jxl:jxl`
- `//third_party/lcms2:lcms2`
- `//third_party/lensfun:lensfun`
- `//third_party/lensfun:lensfun_data`
- `//third_party/openexr:openexr`
- `//third_party/openjpeg:openjpeg`
- `//third_party/png:png`
- `//third_party/pugixml:pugixml`
- `//third_party/sqlite:sqlite`
- `//third_party/tiff:tiff`
- `//third_party/webp:webp`
- `//third_party/webp:webpmux`
- `//third_party/xml:xml`
- `//third_party/zlib:zlib`

The `libpng` BCR module is patched through `single_version_override` to add
`PNG_NO_CONFIG_H`. The repository-wide Bazel configuration defines
`HAVE_CONFIG_H` for darktable sources, and libpng's upstream sources otherwise
interpret that as a request for an Autoconf-generated `config.h`.

The `libwebp` BCR module is patched through `single_version_override` to undefine
`HAVE_CONFIG_H` for libwebp compilation. This avoids libwebp interpreting
darktable's repository-wide configure macro as a request for its own generated
`src/webp/config.h`.

The `libxml2` BCR module is patched through `single_version_override` so its
root `config.h` does not leak `PACKAGE_*` macros into darktable compile
actions. Libxml2 itself still sees those macros because the patch only suppresses
them when darktable's Bazel compile define is present.

The `openexr` BCR module is patched through `single_version_override` to compile
`OpenEXRCore` with `_DEFAULT_SOURCE`. Darktable's global `_XOPEN_SOURCE=700`
otherwise hides glibc's endian conversion macros from `<endian.h>`.

The `icu` BCR module does not expose pkg-config-like `icu-uc`, `icu-i18n`, and
`icu-io` aliases. `//third_party/icu:icu` is a narrow aggregate over the ICU
targets needed by `src/common/sqliteicu.c`. The darktable core targets compile
that shim with `SQLITE_CORE` and `SQLITE_ENABLE_ICU`; those defines are kept out
of the repo-wide Bazel flags so the external SQLite dependency is not rebuilt
against mismatched ICU headers. The Bazel runtime tree packages `icudt78l.dat`
from the ICU source release and the generated launcher exports `ICU_DATA` to
that directory.

Lensfun is pinned to the upstream 0.3.4 GitHub release because it is not
available in BCR and darktable explicitly rejects the 0.3.95 development line.
`//third_party/lensfun:lensfun` builds the small C++ library from source while
using GLib from the existing GTK/GLib system boundary. The library's configured
system database paths are intentionally invalid under Bazel so the runtime uses
darktable's existing fallback to `share/lensfun/version_1` next to
`share/darktable`; `//src:bazel_runtime_tree` packages the release XML database
there.

curl uses the BCR `curl` module and is exposed through `//third_party/curl:curl`.
The BCR module owns the TLS backend and support-library closure; darktable does
not keep a parallel `pkg-config` libcurl dependency.

JPEG XL uses the upstream libjxl 0.11.2 GitHub release through a Bzlmod
`archive_override` because libjxl is not currently available in BCR. The
root-owned `//third_party/jxl:jxl` target aggregates libjxl's `jpegxl` and
`jpegxl_threads` targets. Brotli, Highway, and skcms come from BCR. The libjxl
archive is patched so its Bazel files load `rules_cc` explicitly and expose the
core library targets outside the archive. Brotli is patched to avoid a conflict
between its pedantic C flags and darktable's repo-wide C99 default. Highway is
patched to publish its repository root as an include path so libjxl's
angle-bracket `<hwy/...>` includes resolve to the BCR Highway headers rather
than host headers under `/usr/include`.

Little CMS and OpenJPEG are currently pinned source archives rather than BCR
modules:

- `@lcms2` uses Little CMS 2.19 from the upstream GitHub release archive with a
  small `third_party/lcms2/lcms2.BUILD` overlay.
- `@openjpeg` uses OpenJPEG 2.5.4 from the upstream GitHub release archive with
  a small `third_party/openjpeg/openjpeg.BUILD` overlay and an
  `openjpeg_config.patch` that materializes the CMake-generated OpenJPEG config
  headers for the library build.

Darktable sources force-include the generated Bazel config as `src/config.h`.
Using the package-qualified path is intentional: several migrated dependencies
ship their own `config.h`, and plain `config.h` is ambiguous once those include
roots are in the action.

## Hermeticity Boundary

The intended long-term boundary is:

- Keep GTK and closely coupled desktop integration libraries as system
  dependencies.
- Move leaf libraries into Bazel over time, built from pinned source archives
  through Bzlmod.

The current build is intentionally transitional. `@gtk_stack` represents the
explicit GTK-system boundary. `@darktable_linux_system_probe` aggregates
unmigrated dependencies through `pkg-config` so the Linux build can compile and
link while native external repositories are added incrementally.

The migrated leaf set is zlib, SQLite, pugixml, curl, JPEG XL, libpng,
libjpeg-turbo, libxml2, WebP, libtiff, Little CMS, OpenJPEG, AVIF, HEIF, Imath,
OpenEXR, ICU, and Lensfun.
RawSpeed and LibRaw now depend on the root-owned JPEG/zlib aliases instead of
using `-ljpeg`, `-lz`, and the aggregate pkg-config probe.

Leaf dependencies still flowing through the transitional probe include Exiv2,
libgphoto2, Wayland client symbols, GraphicsMagick, and similar libraries.
Wayland remains system-provided with GTK/GDK because the code uses it as part of
the GTK desktop backend boundary rather than as an isolated leaf library.

## pkg-config Rule

`bazel/pkg_config.bzl` defines `pkg_config_repository`.

For each repository instance, it runs:

```sh
pkg-config --cflags --libs <packages...>
```

The rule splits the output into:

- `copts` for preprocessor and compiler flags.
- `linkopts` for linker flags.
- symlinked include roots named `include_N`.

The generated repository exposes a single target:

```starlark
@repo_name//:pkg
```

The include directories are symlinked into the external repository and listed
in `hdrs`, which lets Bazel's strict include checking understand system headers
instead of treating every system include as undeclared.

This rule is intentionally simple. It is not a complete replacement for a
native external dependency model, and it should shrink as leaf dependencies
move in-tree.

## Generated Files

`bazel/darktable_gen.bzl` centralizes generated build artifacts needed by the
core source targets:

- `config.h`
- `version_gen.c`
- `tools/darktable_authors.h`
- `darktableconfig.dtd`
- `darktableconfig.xml`
- `darktablerc`
- `preferences_gen.h`
- `conf_gen.h`
- `styles_string.h`

These are generated with Bazel `genrule`s using existing darktable scripts and
data files wherever practical. The generated `config.h` is currently a
Linux-focused static approximation of CMake configure output for the milestone
target.

## Source Targets

`src/BUILD.bazel` is organized around granular core libraries to keep rebuilds
localized:

- `darktable_public_headers`
- `darktable_bauhaus`
- `darktable_common`
- `darktable_control`
- `darktable_develop`
- `darktable_dtgtk`
- `darktable_gui`
- `darktable_imageio_core`
- `darktable_module_apis`
- `darktable_lua`
- `darktable_pwstorage`

`darktable_core_compile` joins those libraries and the generated version source
into the shared core used by the milestone binaries.

The plugin shared libraries are built and laid out by category:

- `iop_plugins`
- `view_plugins`
- `lighttable_plugins`
- `imageio_format_plugins`
- `imageio_storage_plugins`

The corresponding runtime layout targets are:

- `iop_plugin_runtime_layout`
- `view_plugin_runtime_layout`
- `lighttable_plugin_runtime_layout`
- `imageio_format_plugin_runtime_layout`
- `imageio_storage_plugin_runtime_layout`

`bazel/dt_runtime.bzl` assembles the fuller runtime tree. It deliberately uses
a functional Bazel layout rather than trying to mirror every CMake install
destination exactly.

IOP plugins are compiled from generated introspection sources produced by
`tools/introspection/parser.pl`, matching the CMake module pattern. Generic
plugin categories use the same forced API includes as CMake:

- IOP: `common/module_api.h` and `iop/iop_api.h`
- Views: `common/module_api.h` and `views/view_api.h`
- Lighttable/libs: `common/module_api.h` and `libs/lib_api.h`
- Image I/O format: `common/module_api.h` and
  `imageio/format/imageio_format_api.h`
- Image I/O storage: `common/module_api.h` and
  `imageio/storage/imageio_storage_api.h`

Some source files are implementation fragments included by other translation
units, not independent compilation units. Those are declared through
`textual_hdrs`; examples include:

- `develop/masks/detail.c`
- `develop/pixelpipe_cache.c`
- `develop/pixelpipe_hb.c`

Header declarations are deliberately granular where practical. The explicit
header list in `CORE_HDRS` exists to make strict include checking useful and to
avoid hiding accidental dependencies behind broad source globs.

## Third-Party Targets

The third-party BUILD files under `bazel/third_party/` model vendored source
trees that already exist in the darktable checkout.

Notable details:

- `rawspeed.BUILD` generates a minimal `rawspeedconfig.h` and builds RawSpeed
  from `src/librawspeed`.
- `libraw.BUILD` generates a minimal `libraw/libraw_config.h` and builds
  LibRaw with the codecs needed by the current milestone.
- `lua.BUILD` builds the vendored Lua library, excluding the standalone Lua
  command-line tools.
- `lautoc.BUILD` builds LuaAutoC against the vendored Lua target.

These are source-tree-local rules, not yet pinned remote archive dependencies.
Moving them to Bzlmod module extensions or explicit archive repositories is a
reasonable follow-up once the native build shape settles.

## Current Limitations

The Bazel build is not a replacement for the full CMake build yet. Known gaps:

- Only Linux is currently configured.
- macOS support needs a platform configuration, framework handling, and
  replacements for Linux-specific feature probes and link options.
- `bazel_runtime_tree` is a runnable tree, not a distro package or system
  installation target.
- The generated `config.h` is a Linux milestone approximation rather than a
  complete configure system.
- `linux_full` feature coverage is incomplete.
- Several non-leaf or broader libraries still come from `pkg-config` and system
  packages.
- Translated desktop/appstream metadata, manpages, documentation, and package
  artifacts are not modeled.
- PortMidi is not modeled in the base Linux plugin milestone because this host
  does not provide `portmidi.h`, `libportmidi`, or `portmidi.pc`; CMake would
  also skip the MIDI plugin in that environment.

Despite those limitations, the current milestone is useful as a strict,
sandboxed compile/link check for a substantial native darktable build under
Bazel.
