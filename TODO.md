# Bazel Build TODO

- Move leaf `pkg-config` dependencies in-tree over time and build them from pinned source archives with Bzlmod. Keep the GTK desktop stack as the explicit system exception, but replace transitional probes for libraries such as image codecs, compression libraries, metadata libraries, and small utility libraries with native Bazel external repositories.
- Expand `linux_full` feature coverage: map/OSMGpsMap, print/CUPS, colord/colord-gtk, libsecret, GMIC compressed LUTs, ImageMagick, AI/ONNXRuntime, cmstest, chart tools/tests, basecurve tools, and noise tools.
- Add PortMidi support for the MIDI lighttable plugin once `portmidi.h`, `libportmidi`, and/or `portmidi.pc` are available on the build host or modeled hermetically.
- Replace the static Linux `config.h` approximation with explicit Bazel feature configuration or probes that track the CMake feature matrix.
- Add macOS support with platform-specific configuration, framework linking, install-name/RPATH handling, and replacements for Linux-only linker and sandbox options.
- Add Bazel test coverage for unit tests, integration tests where practical, plugin loading smoke tests, and runtime-tree smoke tests using both `--moduledir` and `--datadir`.
- Add real packaging/install artifacts after the functional runtime tree settles, such as tar archives and distro package inputs.
- Model translated desktop/appstream metadata, manpages, and generated documentation rather than the current minimal unlocalized runtime metadata.
