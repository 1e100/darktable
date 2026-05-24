# Bazel Build TODO

- Continue moving leaf `pkg-config` dependencies in-tree under `third_party/` and build them from pinned source archives with Bzlmod. Migrated leaves now include zlib, SQLite, pugixml, libpng, libjpeg-turbo, libxml2, WebP, libtiff, Little CMS, OpenJPEG, AVIF, HEIF, Imath, OpenEXR, and ICU. Keep the GTK desktop stack as the explicit system exception.
- Keep evaluating remaining plausible leaves before tackling broad stacks. Lensfun is the main remaining candidate, but it needs runtime database packaging in addition to the library. PortMidi is optional and should remain separate from the base milestone unless the MIDI plugin is intentionally enabled.
- Track BCR/source-overlay maintenance for migrated leaves: libwebp currently needs a BCR patch to avoid its missing generated `src/webp/config.h`, libxml2 needs a BCR patch to avoid leaking package `config.h` macros into darktable compile actions, OpenEXR needs a BCR patch so `OpenEXRCore` sees glibc endian macros under the repo-wide `_XOPEN_SOURCE=700`, and OpenJPEG currently needs a small source-archive patch to materialize CMake-generated config headers.
- Package or otherwise model ICU runtime data for the Bazel runtime tree. The current `//third_party/icu:icu` aggregate links BCR ICU stub data and is sufficient for the build, but real collation/regex behavior should be smoke-tested against runtime data before claiming full ICU parity.
- Defer gnarly or broad dependency stacks: GTK/Cairo/Pango/Rsvg/GLib, libgphoto2, Wayland/desktop integration, Exiv2, libcurl/TLS, GraphicsMagick, and JPEG XL.
- Expand `linux_full` feature coverage: map/OSMGpsMap, print/CUPS, colord/colord-gtk, libsecret, GMIC compressed LUTs, ImageMagick, AI/ONNXRuntime, cmstest, chart tools/tests, basecurve tools, and noise tools.
- Add PortMidi support for the MIDI lighttable plugin once `portmidi.h`, `libportmidi`, and/or `portmidi.pc` are available on the build host or modeled hermetically.
- Replace the static Linux `config.h` approximation with explicit Bazel feature configuration or probes that track the CMake feature matrix.
- Add macOS support with platform-specific configuration, framework linking, install-name/RPATH handling, and replacements for Linux-only linker and sandbox options.
- Add Bazel test coverage for unit tests, integration tests where practical, plugin loading smoke tests, and runtime-tree smoke tests using both `--moduledir` and `--datadir`.
- Add real packaging/install artifacts after the functional runtime tree settles, such as tar archives and distro package inputs.
- Model translated desktop/appstream metadata, manpages, and generated documentation rather than the current minimal unlocalized runtime metadata.
