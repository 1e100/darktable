#!/usr/bin/env bash
set -euo pipefail

if ! command -v apt-get >/dev/null 2>&1; then
  echo "install_deps.sh expects an Ubuntu/Debian system with apt-get." >&2
  exit 1
fi

sudo_cmd=()
if [[ ${EUID} -ne 0 ]]; then
  sudo_cmd=(sudo)
fi

packages=(
  # Local C/C++ toolchain used by Bazel's default Linux C++ toolchain.
  build-essential

  # Tools used by Bazel repository rules and genrules.
  pkg-config
  perl
  xsltproc

  # Display harness for bounded GUI startup smoke tests.
  xvfb
  xauth

  # GTK/desktop stack kept as the explicit system boundary.
  libgtk-3-dev
  libglib2.0-dev
  libgdk-pixbuf-2.0-dev
  libcairo2-dev
  libpango1.0-dev
  libatk1.0-dev
  librsvg2-dev
  libjson-glib-dev
  libwayland-dev

  # Optional Linux desktop integrations enabled by the Bazel Linux config.
  libcolord-dev
  libcolord-gtk-dev
  libx11-dev
  libxrandr-dev
  libsecret-1-dev
  libosmgpsmap-1.0-dev
  libcups2-dev
  libgmic-dev
  libarchive-dev

  # libgphoto2 keeps upstream module loading through system libltdl for now.
  libltdl-dev
)

"${sudo_cmd[@]}" apt-get update
"${sudo_cmd[@]}" apt-get install -y "${packages[@]}"
