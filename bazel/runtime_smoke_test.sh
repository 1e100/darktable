#!/bin/sh
set -eu

fail() {
  echo "runtime smoke test failed: $*" >&2
  exit 1
}

root_arg="${1:?missing runtime tree path}"

resolve_runtime_root() {
  for candidate in \
    "$root_arg" \
    "$PWD/$root_arg" \
    "${TEST_SRCDIR:-}/${TEST_WORKSPACE:-}/$root_arg" \
    "${TEST_SRCDIR:-}/$root_arg"
  do
    if [ -d "$candidate" ]; then
      CDPATH= cd -- "$candidate" && pwd
      return 0
    fi
  done
  return 1
}

runtime_root="$(resolve_runtime_root)" || fail "could not locate runtime tree: $root_arg"

tmp="${TEST_TMPDIR:-/tmp}/darktable-runtime-smoke"
rm -rf "$tmp"
mkdir -p "$tmp/home" "$tmp/config" "$tmp/cache" "$tmp/data"

export HOME="$tmp/home"
export XDG_CONFIG_HOME="$tmp/config"
export XDG_CACHE_HOME="$tmp/cache"
export XDG_DATA_HOME="$tmp/data"

require_file() {
  [ -f "$runtime_root/$1" ] || fail "missing file: $1"
}

require_dir() {
  [ -d "$runtime_root/$1" ] || fail "missing directory: $1"
}

require_executable() {
  require_file "$1"
  [ -x "$runtime_root/$1" ] || fail "not executable: $1"
}

require_executable "bin/darktable"
require_executable "bin/darktable-cli"
require_executable "bin/darktable-generate-cache"
require_executable "bin/darktable-bazel"

require_file "lib/darktable/libdarktable.so"

require_dir "lib/darktable/views"
require_dir "lib/darktable/plugins"
require_dir "lib/darktable/plugins/lighttable"
require_dir "lib/darktable/plugins/imageio/format"
require_dir "lib/darktable/plugins/imageio/storage"

require_file "lib/darktable/views/libdarkroom.so"
require_file "lib/darktable/views/liblighttable.so"
require_file "lib/darktable/plugins/libexposure.so"
require_file "lib/darktable/plugins/lighttable/libcollect.so"
require_file "lib/darktable/plugins/imageio/format/libjpeg.so"
require_file "lib/darktable/plugins/imageio/storage/libdisk.so"

require_dir "share/darktable"
require_file "share/darktable/rawspeed/cameras.xml"
require_file "share/darktable/icu/icudt78l.dat"
require_file "share/darktable/darktablerc"
require_file "share/darktable/darktableconfig.xml"
require_file "share/lensfun/version_1/timestamp.txt"
require_file "share/lensfun/version_1/slr-canon.xml"
require_dir "share/locale"

export ICU_DATA="$runtime_root/share/darktable/icu"

run_and_expect() {
  label="$1"
  pattern="$2"
  shift 2

  set +e
  output="$("$@" 2>&1)"
  status="$?"
  set -e

  printf "%s\n" "$output" | grep -F "$pattern" >/dev/null || {
    printf "%s\n" "$output" >&2
    fail "$label output did not contain '$pattern'"
  }

  case "$label:$status" in
    darktable-bazel:0|darktable-bazel:1|darktable-cli:0|darktable-generate-cache:0|darktable-generate-cache:1)
      ;;
    *)
      printf "%s\n" "$output" >&2
      fail "$label exited with unexpected status $status"
      ;;
  esac
}

run_and_expect "darktable-bazel" "darktable" "$runtime_root/bin/darktable-bazel" "--version"
run_and_expect "darktable-cli" "darktable" "$runtime_root/bin/darktable-cli" "--version"
run_and_expect "darktable-generate-cache" "darktable-generate-cache" "$runtime_root/bin/darktable-generate-cache" "--version"
