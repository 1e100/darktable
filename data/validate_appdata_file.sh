#!/bin/sh
set -eu

command -v appstream-util >/dev/null || {
  echo "appstream-util is required; install appstream-util." >&2
  exit 1
}

appstream-util validate --nonet "$1"
