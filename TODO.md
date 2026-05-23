# Bazel Build TODO

- Move leaf `pkg-config` dependencies in-tree over time and build them from pinned source archives with Bzlmod. Keep the GTK desktop stack as the explicit system exception, but replace transitional probes for libraries such as image codecs, compression libraries, metadata libraries, and small utility libraries with native Bazel external repositories.
