# Bazel Build TODO

- Continue moving leaf `pkg-config` dependencies in-tree under `third_party/` and build them from pinned source archives with Bzlmod. The first migrated BCR-backed set is zlib, SQLite, pugixml, libpng, and libjpeg-turbo. Keep the GTK desktop stack as the explicit system exception.
- Next leaf candidates: lcms2, libxml2, libtiff, OpenJPEG, lensfun, and PortMidi. Prefer BCR modules where usable; otherwise add local `third_party/<name>` overlays with pinned source archives.
- Revisit WebP migration. BCR has `libwebp`, but the current module overlay failed in this repo with a missing generated `src/webp/config.h`; keep `libwebp` and `libwebpmux` on `pkg-config` until that is patched or replaced with a local overlay.
- Defer gnarly or broad dependency stacks: GTK/Cairo/Pango/Rsvg/GLib, libgphoto2, Wayland/desktop integration, Exiv2, libcurl/TLS, OpenEXR/Imath, ICU, GraphicsMagick, SDL, AVIF/HEIF/JPEG XL.
- Expand `linux_full` feature coverage: map/OSMGpsMap, print/CUPS, colord/colord-gtk, libsecret, GMIC compressed LUTs, ImageMagick, AI/ONNXRuntime, cmstest, chart tools/tests, basecurve tools, and noise tools.
- Add PortMidi support for the MIDI lighttable plugin once `portmidi.h`, `libportmidi`, and/or `portmidi.pc` are available on the build host or modeled hermetically.
- Replace the static Linux `config.h` approximation with explicit Bazel feature configuration or probes that track the CMake feature matrix.
- Add macOS support with platform-specific configuration, framework linking, install-name/RPATH handling, and replacements for Linux-only linker and sandbox options.
- Add Bazel test coverage for unit tests, integration tests where practical, plugin loading smoke tests, and runtime-tree smoke tests using both `--moduledir` and `--datadir`.
- Add real packaging/install artifacts after the functional runtime tree settles, such as tar archives and distro package inputs.
- Model translated desktop/appstream metadata, manpages, and generated documentation rather than the current minimal unlocalized runtime metadata.
