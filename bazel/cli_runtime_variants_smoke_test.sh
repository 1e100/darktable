#!/bin/sh
set -eu

DT_SMOKE_NAME="CLI runtime variants smoke test"

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

tmp="${TEST_TMPDIR:-/tmp}/darktable-cli-runtime-variants-smoke"
dt_prepare_runtime_env "$runtime_root" "$tmp"

input="$runtime_root/share/darktable/style/image-1.jpg"

[ -x "$runtime_root/bin/darktable-cli" ] || dt_smoke_fail "missing darktable-cli binary"
[ -f "$input" ] || dt_smoke_fail "missing test input: $input"
[ -f "$ICU_DATA/icudt78l.dat" ] || dt_smoke_fail "missing ICU data"
[ -d "$CAMLIBS" ] || dt_smoke_fail "missing libgphoto2 camera module directory"
[ -d "$IOLIBS" ] || dt_smoke_fail "missing libgphoto2 port module directory"

run_help_and_expect() {
  label="${1:?missing label}"
  pattern="${2:?missing pattern}"
  shift 2

  log="$tmp/$label.log"
  set +e
  "$runtime_root/bin/darktable-cli" "$@" >"$log" 2>&1
  status="$?"
  set -e

  case "$status" in
    0|1)
      ;;
    *)
      cat "$log" >&2
      dt_smoke_fail "$label exited with unexpected status $status"
      ;;
  esac

  grep -F "$pattern" "$log" >/dev/null || {
    cat "$log" >&2
    dt_smoke_fail "$label output did not contain '$pattern'"
  }
}

export_image() {
  label="${1:?missing label}"
  output="${2:?missing output}"
  expected_magic="${3:?missing expected magic}"
  magic_bytes="${4:?missing magic byte count}"

  case_tmp="$tmp/$label"
  mkdir -p "$case_tmp/config" "$case_tmp/cache" "$case_tmp/tmp" "$case_tmp/out"
  log="$case_tmp/darktable-cli.log"

  dt_run_with_timeout "$label" 60 "$log" \
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
    --configdir "$case_tmp/config/darktable" \
    --cachedir "$case_tmp/cache/darktable" \
    --tmpdir "$case_tmp/tmp" \
    --disable-opencl

  [ -s "$output" ] || {
    cat "$log" >&2
    dt_smoke_fail "$label did not write a nonempty output"
  }

  magic="$(dt_file_magic "$magic_bytes" "$output")"
  [ "$magic" = "$expected_magic" ] || {
    cat "$log" >&2
    dt_smoke_fail "$label wrote unexpected magic '$magic', expected '$expected_magic'"
  }

  grep -F "[export_job] exported to" "$log" >/dev/null || {
    cat "$log" >&2
    dt_smoke_fail "$label output did not report an export"
  }
}

run_help_and_expect "help" "Usage:" --help
run_help_and_expect "help-icc-type" "supported types" --help icc-type
run_help_and_expect "help-icc-intent" "supported intents" --help icc-intent

export_image "export-jpeg" "$tmp/out/export.jpg" "ffd8" 2
export_image "export-png" "$tmp/out/export.png" "89504e47" 4
