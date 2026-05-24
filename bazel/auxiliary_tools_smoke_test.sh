#!/bin/sh
set -eu

cmstest="$1"
chart="$2"
curve_tool="$3"
noiseprofile="$4"

tmp="${TEST_TMPDIR:-/tmp}/darktable-auxiliary-tools-smoke"
rm -rf "$tmp"
mkdir -p "$tmp"

if "$cmstest" >"$tmp/cmstest.out" 2>&1; then
  :
fi
grep -F "darktable-cmstest version" "$tmp/cmstest.out" >/dev/null

if "$chart" --help >"$tmp/chart.out" 2>&1; then
  :
fi
grep -F "Usage:" "$tmp/chart.out" >/dev/null
grep -F "darktable-chart" "$tmp/chart.out" >/dev/null

if "$curve_tool" -h >"$tmp/curve-tool.out" 2>&1; then
  :
fi
grep -F "darktable-curve-tool" "$tmp/curve-tool.out" >/dev/null
grep -F "Print this help message" "$tmp/curve-tool.out" >/dev/null

if "$noiseprofile" >"$tmp/noiseprofile.out" 2>&1; then
  :
fi
grep -F "usage:" "$tmp/noiseprofile.out" >/dev/null
grep -F "darktable-noiseprofile" "$tmp/noiseprofile.out" >/dev/null
