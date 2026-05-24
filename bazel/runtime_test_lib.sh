#!/bin/sh

dt_smoke_fail() {
  echo "${DT_SMOKE_NAME:-darktable runtime smoke test} failed: $*" >&2
  exit 1
}

dt_resolve_runtime_root() {
  root_arg="${1:?missing runtime tree path}"

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

dt_prepare_runtime_env() {
  runtime_root="${1:?missing runtime root}"
  tmp="${2:?missing temp root}"

  rm -rf "$tmp"
  mkdir -p "$tmp/home" "$tmp/config" "$tmp/cache" "$tmp/data" "$tmp/tmp" "$tmp/out"

  export HOME="$tmp/home"
  export XDG_CONFIG_HOME="$tmp/config"
  export XDG_CACHE_HOME="$tmp/cache"
  export XDG_DATA_HOME="$tmp/data"
  export ICU_DATA="$runtime_root/share/darktable/icu"
  export CAMLIBS="$runtime_root/lib/darktable/libgphoto2/2.5.33"
  export IOLIBS="$runtime_root/lib/darktable/libgphoto2_port/0.12.2"
}

dt_require_file() {
  [ -f "$runtime_root/$1" ] || dt_smoke_fail "missing file: $1"
}

dt_require_dir() {
  [ -d "$runtime_root/$1" ] || dt_smoke_fail "missing directory: $1"
}

dt_require_executable() {
  dt_require_file "$1"
  [ -x "$runtime_root/$1" ] || dt_smoke_fail "not executable: $1"
}

dt_run_with_timeout() {
  label="${1:?missing label}"
  timeout_seconds="${2:?missing timeout}"
  log="${3:?missing log}"
  shift 3

  "$@" >"$log" 2>&1 &
  command_pid="$!"

  (
    sleep "$timeout_seconds"
    if kill -0 "$command_pid" 2>/dev/null; then
      echo "$label timed out" >>"$log"
      kill "$command_pid" 2>/dev/null || true
      sleep 2
      kill -KILL "$command_pid" 2>/dev/null || true
    fi
  ) &
  watchdog_pid="$!"

  set +e
  wait "$command_pid"
  status="$?"
  set -e

  kill "$watchdog_pid" 2>/dev/null || true
  wait "$watchdog_pid" 2>/dev/null || true

  if [ "$status" -ne 0 ]; then
    cat "$log" >&2
    dt_smoke_fail "$label exited with status $status"
  fi
}

dt_file_magic() {
  bytes="${1:?missing byte count}"
  path="${2:?missing file path}"
  od -An -tx1 -N"$bytes" "$path" | tr -d ' \n'
}
