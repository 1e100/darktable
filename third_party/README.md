# Third-Party Bazel Dependencies

This tree contains darktable-owned Bazel integration points for leaf
dependencies that no longer flow through the transitional Linux `pkg-config`
probe.

Prefer Bazel Central Registry modules when they exist. Keep local aliases here
stable so source targets depend on labels such as `//third_party/jpeg:jpeg`
rather than on provider-specific external repository labels. If a dependency is
not available in BCR, add the source/build overlay under `third_party/<name>/`
and document why it is local.

GTK and closely coupled desktop libraries remain system dependencies. Pinned
source leaves that still use GLib should depend on the existing GTK/GLib
boundary rather than adding a second broad desktop dependency set.
