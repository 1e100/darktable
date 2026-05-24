#!/bin/sh
set -eu

fail() {
  echo "sqlite ICU smoke test failed: $*" >&2
  exit 1
}

binary_arg="${1:?missing smoke binary path}"
runtime_arg="${2:?missing runtime tree path}"

resolve_path() {
  path="$1"
  for candidate in \
    "$path" \
    "$PWD/$path" \
    "${TEST_SRCDIR:-}/${TEST_WORKSPACE:-}/$path" \
    "${TEST_SRCDIR:-}/$path"
  do
    if [ -e "$candidate" ]; then
      CDPATH= cd -- "$(dirname -- "$candidate")" && printf "%s/%s\n" "$(pwd)" "$(basename -- "$candidate")"
      return 0
    fi
  done
  return 1
}

resolve_dir() {
  path="$1"
  for candidate in \
    "$path" \
    "$PWD/$path" \
    "${TEST_SRCDIR:-}/${TEST_WORKSPACE:-}/$path" \
    "${TEST_SRCDIR:-}/$path"
  do
    if [ -d "$candidate" ]; then
      CDPATH= cd -- "$candidate" && pwd
      return 0
    fi
  done
  return 1
}

smoke_binary="$(resolve_path "$binary_arg")" || fail "could not locate smoke binary: $binary_arg"
runtime_root="$(resolve_dir "$runtime_arg")" || fail "could not locate runtime tree: $runtime_arg"

icu_dir="$runtime_root/share/darktable/icu"
[ -f "$icu_dir/icudt78l.dat" ] || fail "missing ICU data file"

export ICU_DATA="$icu_dir"
exec "$smoke_binary"
