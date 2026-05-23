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

It also keeps source filegroups for image operation, view, lighttable, and
image I/O modules in the graph. Those module filegroups are not yet complete
plugin shared-library builds.

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
  HEIF, OpenEXR, OpenJPEG, SDL, PortMidi, ICU, and OpenMP.

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

## Hermeticity Boundary

The intended long-term boundary is:

- Keep GTK and closely coupled desktop integration libraries as system
  dependencies.
- Move leaf libraries into Bazel over time, built from pinned source archives
  through Bzlmod.

The current build is intentionally transitional. `@gtk_stack` represents the
explicit GTK-system boundary. `@darktable_linux_system_probe` aggregates many
leaf dependencies through `pkg-config` so the initial Linux build can compile
and link while the native external repositories are added incrementally.

Leaf dependencies still flowing through the transitional probe include image
codecs, metadata libraries, compression libraries, Wayland client symbols, ICU,
SDL, and similar small libraries. `TODO.md` tracks the intent to replace those
with pinned source builds.

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
- Plugin shared libraries are not fully modeled.
- The generated `config.h` is a Linux milestone approximation rather than a
  complete configure system.
- `linux_full` feature coverage is incomplete.
- Many leaf libraries still come from `pkg-config` and system packages.
- Packaging and install layout are not modeled.

Despite those limitations, the current milestone is useful as a strict,
sandboxed compile/link check for a substantial native darktable build under
Bazel.
