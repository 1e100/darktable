#!/bin/sh
set -eu

DT_SMOKE_NAME="GUI init smoke test"

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

binary_arg="${1:?missing GUI init smoke binary path}"
root_arg="${2:?missing runtime tree path}"

resolve_file() {
  for candidate in \
    "$1" \
    "$PWD/$1" \
    "${TEST_SRCDIR:-}/${TEST_WORKSPACE:-}/$1" \
    "${TEST_SRCDIR:-}/$1"
  do
    if [ -f "$candidate" ]; then
      CDPATH= cd -- "$(dirname -- "$candidate")" && printf "%s/%s\n" "$(pwd)" "$(basename -- "$candidate")"
      return 0
    fi
  done
  return 1
}

gui_smoke_binary="$(resolve_file "$binary_arg")" || dt_smoke_fail "could not locate GUI smoke binary: $binary_arg"
runtime_root="$(dt_resolve_runtime_root "$root_arg")" || dt_smoke_fail "could not locate runtime tree: $root_arg"

command -v xvfb-run >/dev/null 2>&1 || {
  dt_smoke_fail "missing xvfb-run; install xvfb and xauth"
}

tmp="${TEST_TMPDIR:-/tmp}/darktable-gui-init-smoke"
mkdir -p "$tmp"
log="$tmp/darktable-gui-init-smoke.log"

export GDK_BACKEND=x11
export NO_AT_BRIDGE=1

dt_run_with_timeout "bazel_gui_init_smoke_test" 90 "$log" \
  xvfb-run \
  -a \
  -s "-screen 0 1280x1024x24" \
  "$gui_smoke_binary" \
  "$runtime_root"
