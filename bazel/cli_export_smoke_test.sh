#!/bin/sh
set -eu

DT_SMOKE_NAME="CLI export smoke test"

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

tmp="${TEST_TMPDIR:-/tmp}/darktable-cli-export-smoke"
dt_prepare_runtime_env "$runtime_root" "$tmp"

input="$runtime_root/share/darktable/style/image-1.jpg"
output="$tmp/out/export.jpg"
log="$tmp/darktable-cli.log"

[ -x "$runtime_root/bin/darktable-cli" ] || dt_smoke_fail "missing darktable-cli binary"
[ -f "$input" ] || dt_smoke_fail "missing test input: $input"
[ -f "$ICU_DATA/icudt78l.dat" ] || dt_smoke_fail "missing ICU data"
[ -d "$CAMLIBS" ] || dt_smoke_fail "missing libgphoto2 camera module directory"
[ -d "$IOLIBS" ] || dt_smoke_fail "missing libgphoto2 port module directory"

dt_run_with_timeout "darktable-cli" 60 "$log" \
  "$runtime_root/bin/darktable-cli" \
  "$input" \
  "$output" \
  --width 64 \
  --height 64 \
  --hq false \
  --core \
  --datadir "$runtime_root/share/darktable" \
  --moduledir "$runtime_root/lib/darktable" \
  --localedir "$runtime_root/share/locale" \
  --configdir "$tmp/config/darktable" \
  --cachedir "$tmp/cache/darktable" \
  --tmpdir "$tmp/tmp" \
  --disable-opencl

[ -s "$output" ] || {
  cat "$log" >&2
  dt_smoke_fail "darktable-cli did not write a nonempty output"
}

magic="$(dt_file_magic 2 "$output")"
[ "$magic" = "ffd8" ] || {
  cat "$log" >&2
  dt_smoke_fail "output is not a JPEG file"
}

grep -F "[export_job] exported to" "$log" >/dev/null || {
  cat "$log" >&2
  dt_smoke_fail "darktable-cli output did not report an export"
}
