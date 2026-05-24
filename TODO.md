# Bazel Build TODO

- Continue moving leaf `pkg-config` dependencies in-tree under `third_party/` and build them from pinned source archives with Bzlmod. Migrated leaves now include zlib, SQLite, pugixml, libpng, libjpeg-turbo, libxml2, WebP, libtiff, Little CMS, and OpenJPEG. Keep the GTK desktop stack as the explicit system exception.
- Keep evaluating remaining plausible leaves before tackling broad stacks. Lensfun is the main remaining candidate, but it needs runtime database packaging in addition to the library. PortMidi is optional and should remain separate from the base milestone unless the MIDI plugin is intentionally enabled.
- Track BCR/source-overlay maintenance for migrated leaves: libwebp currently needs a BCR patch to avoid its missing generated `src/webp/config.h`, libxml2 needs a BCR patch to avoid leaking package `config.h` macros into darktable compile actions, and OpenJPEG currently needs a small source-archive patch to materialize CMake-generated config headers.
- Defer gnarly or broad dependency stacks: GTK/Cairo/Pango/Rsvg/GLib, libgphoto2, Wayland/desktop integration, Exiv2, libcurl/TLS, OpenEXR/Imath, ICU, GraphicsMagick, SDL, AVIF/HEIF/JPEG XL.
- Expand `linux_full` feature coverage: map/OSMGpsMap, print/CUPS, colord/colord-gtk, libsecret, GMIC compressed LUTs, ImageMagick, AI/ONNXRuntime, cmstest, chart tools/tests, basecurve tools, and noise tools.
- Add PortMidi support for the MIDI lighttable plugin once `portmidi.h`, `libportmidi`, and/or `portmidi.pc` are available on the build host or modeled hermetically.
- Replace the static Linux `config.h` approximation with explicit Bazel feature configuration or probes that track the CMake feature matrix.
- Add macOS support with platform-specific configuration, framework linking, install-name/RPATH handling, and replacements for Linux-only linker and sandbox options.
- Add Bazel test coverage for unit tests, integration tests where practical, plugin loading smoke tests, and runtime-tree smoke tests using both `--moduledir` and `--datadir`.
- Add real packaging/install artifacts after the functional runtime tree settles, such as tar archives and distro package inputs.
- Model translated desktop/appstream metadata, manpages, and generated documentation rather than the current minimal unlocalized runtime metadata.
