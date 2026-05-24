#!/bin/sh
set -eu

DT_SMOKE_NAME="runtime smoke test"

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
for helper in \
  "$script_dir/runtime_test_lib.sh" \
  "${TEST_SRCDIR:-}/${TEST_WORKSPACE:-}/bazel/runtime_test_lib.sh" \
  "${TEST_SRCDIR:-}/_main/bazel/runtime_test_lib.sh"
do
  if [ -f "$helper" ]; then
    . "$helper"
    break
  fi
done
command -v dt_smoke_fail >/dev/null 2>&1 || {
  echo "$DT_SMOKE_NAME failed: could not locate runtime_test_lib.sh" >&2
  exit 2
}

root_arg="${1:?missing runtime tree path}"
runtime_root="$(dt_resolve_runtime_root "$root_arg")" || dt_smoke_fail "could not locate runtime tree: $root_arg"

tmp="${TEST_TMPDIR:-/tmp}/darktable-runtime-smoke"
dt_prepare_runtime_env "$runtime_root" "$tmp"

dt_require_executable "bin/darktable"
dt_require_executable "bin/darktable-cli"
dt_require_executable "bin/darktable-chart"
dt_require_executable "bin/darktable-generate-cache"
dt_require_executable "bin/darktable-cmstest"
dt_require_executable "bin/darktable-bazel"
dt_require_executable "libexec/darktable/tools/darktable-curve-tool"
dt_require_executable "libexec/darktable/tools/darktable-curve-tool-helper"
dt_require_executable "libexec/darktable/tools/darktable-gen-noiseprofile"
dt_require_executable "libexec/darktable/tools/darktable-noiseprofile"

dt_require_file "lib/darktable/libdarktable.so"

dt_require_dir "lib/darktable/views"
dt_require_dir "lib/darktable/plugins"
dt_require_dir "lib/darktable/plugins/lighttable"
dt_require_dir "lib/darktable/plugins/imageio/format"
dt_require_dir "lib/darktable/plugins/imageio/storage"

dt_require_file "lib/darktable/views/libdarkroom.so"
dt_require_file "lib/darktable/views/liblighttable.so"
dt_require_file "lib/darktable/plugins/libexposure.so"
dt_require_file "lib/darktable/plugins/lighttable/libcollect.so"
dt_require_file "lib/darktable/plugins/imageio/format/libjpeg.so"
dt_require_file "lib/darktable/plugins/imageio/storage/libdisk.so"
dt_require_file "lib/darktable/libgphoto2/2.5.33/ptp2.so"
dt_require_file "lib/darktable/libgphoto2_port/0.12.2/usb1.so"

dt_require_dir "share/darktable"
dt_require_file "share/darktable/rawspeed/cameras.xml"
dt_require_file "share/darktable/icu/icudt78l.dat"
dt_require_file "share/darktable/darktablerc"
dt_require_file "share/darktable/darktableconfig.xml"
dt_require_file "share/darktable/tools/basecurve/plot.basecurve"
dt_require_file "share/darktable/tools/basecurve/plot.tonecurve"
dt_require_file "share/lensfun/version_1/timestamp.txt"
dt_require_file "share/lensfun/version_1/slr-canon.xml"
dt_require_dir "share/locale"

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
    dt_smoke_fail "$label output did not contain '$pattern'"
  }

  case "$label:$status" in
    darktable-bazel:0|darktable-bazel:1|darktable-cli:0|darktable-generate-cache:0|darktable-generate-cache:1)
      ;;
    *)
      printf "%s\n" "$output" >&2
      dt_smoke_fail "$label exited with unexpected status $status"
      ;;
  esac
}

run_and_expect "darktable-bazel" "darktable" "$runtime_root/bin/darktable-bazel" "--version"
run_and_expect "darktable-cli" "darktable" "$runtime_root/bin/darktable-cli" "--version"
run_and_expect "darktable-generate-cache" "darktable-generate-cache" "$runtime_root/bin/darktable-generate-cache" "--version"
