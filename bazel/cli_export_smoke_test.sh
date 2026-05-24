#!/bin/sh
set -eu

fail() {
  echo "CLI export smoke test failed: $*" >&2
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

tmp="${TEST_TMPDIR:-/tmp}/darktable-cli-export-smoke"
rm -rf "$tmp"
mkdir -p "$tmp/home" "$tmp/config" "$tmp/cache" "$tmp/data" "$tmp/tmp" "$tmp/out"

export HOME="$tmp/home"
export XDG_CONFIG_HOME="$tmp/config"
export XDG_CACHE_HOME="$tmp/cache"
export XDG_DATA_HOME="$tmp/data"
export ICU_DATA="$runtime_root/share/darktable/icu"
export CAMLIBS="$runtime_root/lib/darktable/libgphoto2/2.5.33"
export IOLIBS="$runtime_root/lib/darktable/libgphoto2_port/0.12.2"

input="$runtime_root/share/darktable/style/image-1.jpg"
output="$tmp/out/export.jpg"
log="$tmp/darktable-cli.log"

[ -x "$runtime_root/bin/darktable-cli" ] || fail "missing darktable-cli binary"
[ -f "$input" ] || fail "missing test input: $input"
[ -f "$ICU_DATA/icudt78l.dat" ] || fail "missing ICU data"
[ -d "$CAMLIBS" ] || fail "missing libgphoto2 camera module directory"
[ -d "$IOLIBS" ] || fail "missing libgphoto2 port module directory"

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
  --disable-opencl \
  >"$log" 2>&1 &
cli_pid="$!"

(
  sleep 60
  if kill -0 "$cli_pid" 2>/dev/null; then
    echo "darktable-cli timed out" >>"$log"
    kill "$cli_pid" 2>/dev/null || true
    sleep 2
    kill -KILL "$cli_pid" 2>/dev/null || true
  fi
) &
watchdog_pid="$!"

set +e
wait "$cli_pid"
status="$?"
set -e

kill "$watchdog_pid" 2>/dev/null || true
wait "$watchdog_pid" 2>/dev/null || true

if [ "$status" -ne 0 ]; then
  cat "$log" >&2
  fail "darktable-cli exited with status $status"
fi

[ -s "$output" ] || {
  cat "$log" >&2
  fail "darktable-cli did not write a nonempty output"
}

magic="$(od -An -tx1 -N2 "$output" | tr -d ' \n')"
[ "$magic" = "ffd8" ] || {
  cat "$log" >&2
  fail "output is not a JPEG file"
}

grep -F "[export_job] exported to" "$log" >/dev/null || {
  cat "$log" >&2
  fail "darktable-cli output did not report an export"
}
