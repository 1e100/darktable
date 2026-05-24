#!/bin/sh
set -eu

command -v desktop-file-validate >/dev/null || {
  echo "desktop-file-validate is required; install desktop-file-utils." >&2
  exit 1
}

desktop-file-validate --warn-kde "$1"
