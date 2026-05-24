# Repository Guide

This file is for coding agents and future maintainers working in this checkout.
It summarizes repo conventions, the application shape, and the current state of
the Bazel migration.

## Working Conventions

- Prefer existing darktable patterns over new abstractions. The codebase is
  mature C/C++ with many local conventions around modules, plugins, and runtime
  loading.
- Keep changes tightly scoped. Do not mix CMake cleanup, Bazel migration,
  feature work, and source refactors unless the task explicitly calls for it.
- Treat the CMake build as legacy for this migration. Avoid spending effort
  keeping it green unless the user specifically asks; it is expected to be
  deleted later.
- Use Bazelisk or a `bazel` launcher backed by Bazelisk. `.bazelversion` pins
  the expected Bazel version.
- The current Bazel target platform is Linux. Future macOS support should reuse
  the Bzlmod structure but will need platform-specific config, framework
  linking, install-name/RPATH handling, and replacements for Linux-only flags.
- The repository defaults to C++20 and C99 through `.bazelrc`.
- Do not depend directly on external repository labels from darktable source
  targets when there is a root-owned alias under `third_party/`.
- When adding dependency BUILD files manually, keep them small, pinned, and
  close to the upstream library layout. Prefer BCR modules, then pinned upstream
  release archives with custom BUILD overlays.
- Prefer principled dependency modeling over local compatibility shims. If an
  upstream library depends on a small system or source dependency, model that
  dependency explicitly unless there is a clear reason not to.
- Keep GTK and tightly coupled desktop integration as the explicit system
  boundary. Do not try to hermeticize GTK, Cairo, Pango, Rsvg, GLib, or Wayland
  as part of leaf-dependency work.

## Application Architecture

darktable is a GTK desktop photo workflow application with a shared core library,
CLI binaries, dynamically loaded modules, and a runtime data tree.

Important source areas:

- `src/common/`: core services such as database handling, image metadata,
  configuration, module loading, OpenCL support, mipmap/cache management, and
  integration utilities.
- `src/control/`: job control, background work, and application control flow.
- `src/develop/`: image development pipeline support.
- `src/gui/`: GTK UI infrastructure and desktop backend integration.
- `src/iop/`: image operation plugins. These are built as shared libraries and
  loaded at runtime.
- `src/libs/`: UI/lighttable-side plugins and panels, also loaded as modules.
- `src/views/`: top-level application views such as darkroom, lighttable,
  slideshow, and tethering.
- `src/imageio/format/`: import/export format plugins.
- `src/imageio/storage/`: export storage plugins.
- `src/external/`: vendored source trees used by darktable, including Lua,
  LibRaw, RawSpeed, whereami, libxcf, and LuaAutoC.
- `data/`, `tools/`, `packaging/`, `po/`, and `doc/`: runtime data,
  generated/configured assets, packaging support, translations, and docs.

The Bazel runtime tree must preserve darktable's loader expectations:

- binaries under `bin/`
- `libdarktable.so` under `lib/darktable/`
- view plugins under `lib/darktable/views/`
- IOP plugins under `lib/darktable/plugins/`
- lighttable plugins under `lib/darktable/plugins/lighttable/`
- image I/O plugins under `lib/darktable/plugins/imageio/{format,storage}/`
- runtime data under `share/darktable/`
- locale files under `share/locale/`
- Bazel runfile shared libraries under `lib/darktable/bazel-solib/` for plugin
  dependencies that still use Bazel-generated shared object names

## Bazel Entry Points

Main Linux milestone:

```sh
bazel build --config=linux //src:bazel_build_milestone
```

Other useful targets:

```sh
bazel build --config=linux //third_party/...
bazel build --config=linux //src:bazel_plugin_milestone
bazel build --config=linux //src:bazel_plugin_runtime_layout
bazel build --config=linux //src:bazel_runtime_tree
```

The runnable Bazel launcher is:

```sh
bazel-bin/src/darktable-runtime/bin/darktable-bazel --version
```

For a sandbox verification rebuild:

```sh
bazel build --config=linux --copt=-DDT_BAZEL_SANDBOX_VERIFY //src:bazel_build_milestone
```

## Bazel Structure

- `MODULE.bazel` declares Bzlmod dependencies and repository rules.
- `MODULE.bazel.lock` is checked in and should be updated when dependency
  resolution changes.
- `.bazelrc` enables Bzlmod and sets shared C/C++ defaults.
- `bazel/darktable_features.bzl` owns the current Linux feature configuration
  for generated `config.h`, supported extensions, and generated OpenCL-aware
  preference/config headers. Do not add darktable feature macros back to
  `.bazelrc`; keep them in this Starlark feature map unless a real platform
  probe layer replaces it.
- `bazel/pkg_config.bzl` defines `pkg_config_repository`, the transitional
  system dependency bridge.
- `bazel/third_party/` contains BUILD overlays for vendored source trees under
  `src/external/`.
- `third_party/` contains root-owned aliases and source-archive BUILD overlays
  for migrated dependencies.
- `src/BUILD.bazel` currently models the main binaries, core shared library,
  plugins, generated files, and runtime tree assembly.

The transitional `pkg_config_repository` exposes a single `:pkg` target per
repository. It shells out to `pkg-config`, splits compiler and linker flags, and
symlinks include roots into the external repository so Bazel's include checking
can see host headers.

## Migrated Dependencies

The current leaf dependencies modeled under Bazel are:

- BCR modules: zlib, SQLite, pugixml, Brotli, curl, Highway, libexpat, libpng,
  libjpeg-turbo, libxml2, WebP, libtiff, AVIF, HEIF, Imath, OpenEXR, skcms,
  and ICU.
- Pinned source archives: Little CMS, OpenJPEG, Lensfun, Exiv2, and libjxl.
- Existing vendored local repositories: whereami, libxcf, Lua, LuaAutoC,
  LibRaw, and RawSpeed.

Root-owned aliases currently include:

- `//third_party/avif:avif`
- `//third_party/curl:curl`
- `//third_party/exiv2:exiv2`
- `//third_party/gphoto2:gphoto2`
- `//third_party/gphoto2:gphoto2_runtime`
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

The Bazel build also removed SDL2/gamepad support from both Bazel and CMake.

## Dependency Boundary

Keep these system-provided for now:

- GTK, GLib, GIO, GModule, GThread
- GDK Pixbuf
- Cairo, Pango, PangoCairo, ATK, librsvg
- json-glib
- Wayland client integration used through GTK/GDK desktop backend handling

There is no remaining required transitional probe repository. Wayland client
symbols are part of the GTK/GDK system boundary.

Optional desktop/system feature probes include:

- colord
- colord-gtk
- libsecret
- osmgpsmap
- portmidi

## Known Bazel Patches And Caveats

- libpng is patched so darktable's global `HAVE_CONFIG_H` does not make libpng
  look for its own Autoconf `config.h`.
- libwebp is patched so darktable's global `HAVE_CONFIG_H` does not make WebP
  look for `src/webp/config.h`.
- libxml2 is patched so package `config.h` macros do not leak into darktable
  compile actions when `DT_BAZEL_BUILD` is present.
- OpenJPEG uses a source-archive patch to materialize CMake-generated config
  headers.
- OpenEXR is patched so `OpenEXRCore` compiles with `_DEFAULT_SOURCE`; the
  repo-wide `_XOPEN_SOURCE=700` otherwise hides glibc endian macros.
- ICU is wired as a narrow aggregate for `src/common/sqliteicu.c`. The runtime
  tree packages `icudt78l.dat`, and the Bazel launcher exports `ICU_DATA` so
  SQLite ICU collation initialization can find the data file.
- Lensfun is pinned to upstream 0.3.4 with a local BUILD overlay. It uses GLib
  from the existing GTK/GLib system boundary and packages the XML database under
  `share/lensfun/version_1` in the Bazel runtime tree.
- curl uses the BCR `curl` module through `//third_party/curl:curl`; TLS and
  support libraries come from that module's Bzlmod dependency closure.
- libjxl is pinned to upstream 0.11.2 through a Bzlmod `archive_override`.
  `//third_party/jxl:jxl` aggregates `jpegxl` and `jpegxl_threads`; Brotli,
  Highway, and skcms come from BCR.
- Exiv2 is pinned to upstream 0.28.8 with a local BUILD overlay. The overlay
  builds Exiv2 plus the bundled Adobe XMP SDK, uses BCR `libexpat`, and enables
  PNG/BMFF/Brotli/XMP/filesystem/video support while leaving NLS, webready HTTP
  IO, and inih config parsing disabled.
- libgphoto2 is pinned to upstream 2.5.33 with a local BUILD overlay. It builds
  libgphoto2, libgphoto2_port, the `directory` and `ptp2` camera modules, and
  the `disk`, `ptpip`, `serial`, and `usb1` port modules. USB support uses BCR
  `libusb`; module loading intentionally uses system `libltdl` instead of a
  local compatibility shim. The Bazel runtime launcher exports `CAMLIBS` and
  `IOLIBS` to the packaged module directories.
- Brotli is patched so its strict C flags do not reject anonymous unions under
  darktable's repo-wide C99 default.
- Highway is patched so BCR Highway headers are exported for libjxl's
  angle-bracket includes instead of falling through to host `/usr/include`.
- libxcf is compiled with `_DEFAULT_SOURCE`, matching the legacy CMake path, so
  Linux `htobe*` byte-order macros are visible.

## Remaining Work

- Continue evaluating manageable leaf dependencies for in-tree builds.
- Defer broad or gnarly stacks: GTK/Cairo/Pango/Rsvg/GLib and
  Wayland/desktop integration.
- GraphicsMagick support was intentionally removed rather than migrated. Do not
  reintroduce it; use the optional ImageMagick path for miscellaneous LDR
  fallback imports if that feature is intentionally enabled.
- Continue plugin/runtime cleanup. Plugins now link against `libdarktable.so`
  instead of `darktable_core_compile`, and `bazel_plugin_load_smoke_test`
  exercises headless `dlopen()` plus required API symbol checks across the
  arranged plugin tree. `bazel_plugin_init_smoke_test` is a gtest fixture that
  runs real non-GUI `dt_init()` against the Bazel runtime tree and verifies
  initialized image I/O and IOP module registries. `bazel_cli_export_smoke_test`
  exercises a real JPEG export through the arranged `darktable-cli`.
  `bazel_cli_runtime_variants_smoke_test` adds headless CLI help coverage and
  JPEG/PNG export checks. Remaining coverage should add carefully bounded
  GUI/view initialization.
- Small legacy unit tests now have Bazel coverage through
  `darktable_cache_test`, `darktable_variables_test`, `sample_gtest`,
  `filmicrgb_gtest`, and optional `ai_backend_gtest`. Do not add cmocka to the
  Bazel dependency boundary for those tests; prefer GTest runners or standalone
  C tests. `ai_backend_gtest` requires
  `--//bazel/config:enable_ai=true` plus a local ONNXRuntime install.
- The Linux Bazel configuration models map/OSMGpsMap, print/CUPS,
  colord/colord-gtk, libsecret, GMIC compressed LUTs, X11/Xrandr for
  `darktable-cmstest`, and optional AI/libarchive/ONNXRuntime as system
  dependencies. Auxiliary tool build coverage now includes `darktable-cmstest`,
  `darktable-chart`, `darktable-curve-tool`, and `darktable-noiseprofile`.
  Remaining fuller feature parity work includes ImageMagick and end-to-end
  chart/basecurve/noise workflows.
- Add PortMidi support for the MIDI lighttable plugin only if that plugin is
  intentionally enabled and `portmidi.h`, `libportmidi`, or `portmidi.pc` is
  available or modeled hermetically.
- Add platform/compiler probes where hard-coded Linux feature values are not
  appropriate, especially before introducing macOS support.
- Add macOS support.
- Add Bazel test coverage for unit tests, integration tests where practical,
  and runtime-tree smoke tests using both `--moduledir` and `--datadir`.
- Add install/package artifacts after the functional runtime tree settles.
- Model translated desktop/appstream metadata, manpages, and generated docs.

## Verification Expectations

For dependency/build-graph changes, run:

```sh
bazel build --config=linux //third_party/...
bazel build --config=linux //src:bazel_build_milestone
git diff --check
```

For runtime-layout changes, also run:

```sh
bazel build --config=linux //src:bazel_runtime_tree
bazel test --config=linux //src:darktable_cache_test //src:darktable_variables_test //src:sample_gtest //src:filmicrgb_gtest
bazel test --config=linux //src:bazel_runtime_smoke_test
bazel test --config=linux //src:bazel_plugin_load_smoke_test
bazel test --config=linux //src:bazel_plugin_init_smoke_test
bazel test --config=linux //src:bazel_cli_export_smoke_test
bazel test --config=linux //src:bazel_cli_runtime_variants_smoke_test
bazel test --config=linux //src:bazel_sqliteicu_smoke_test
bazel test --config=linux //src:bazel_auxiliary_tools_smoke_test
bazel-bin/src/darktable-runtime/bin/darktable-bazel --version
```
