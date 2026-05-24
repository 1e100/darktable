#!/bin/sh
set -eu

fail() {
  echo "config feature smoke test failed: $*" >&2
  exit 1
}

config_h="${1:?missing generated config.h path}"
darktableconfig_xml="${2:?missing generated darktableconfig.xml path}"

require_line() {
  file="$1"
  pattern="$2"
  grep -F "$pattern" "$file" >/dev/null || fail "missing '$pattern' in $file"
}

reject_line() {
  file="$1"
  pattern="$2"
  if grep -F "$pattern" "$file" >/dev/null; then
    fail "unexpected '$pattern' in $file"
  fi
}

require_default_after_name() {
  file="$1"
  name="$2"
  expected="$3"
  awk -v name="$name" -v expected="$expected" '
    $0 ~ "<name>" name "</name>" { found = 1; next }
    found && $0 ~ "<default>" {
      if($0 ~ "<default>" expected "</default>") exit 0
      exit 1
    }
    found && $0 ~ "</dtconfig>" { exit 1 }
  ' "$file" || fail "expected default '$expected' for '$name' in $file"
}

require_line "$config_h" "#define HAVE_OPENCL 1"
require_line "$config_h" "#define CL_TARGET_OPENCL_VERSION 300"
require_line "$config_h" '#define SHARED_MODULE_SUFFIX ".so"'

require_default_after_name "$darktableconfig_xml" "opencl" "true"
require_default_after_name "$darktableconfig_xml" "clplatform_intelropenclhdgraphics" "true"
require_default_after_name "$darktableconfig_xml" "clplatform_nvidiacuda" "true"
require_default_after_name "$darktableconfig_xml" "clplatform_rusticl" "true"
require_default_after_name "$darktableconfig_xml" "clplatform_apple" "false"
require_default_after_name "$darktableconfig_xml" "ui_last/audio_player" "aplay"
reject_line "$darktableconfig_xml" '${DEFCONFIG_APPLE}'
reject_line "$darktableconfig_xml" '${DEFCONFIG_NONAPPLE}'
reject_line "$darktableconfig_xml" '${DEFCONFIG_OPENCL}'
reject_line "$darktableconfig_xml" '${DEFCONFIG_AUDIOPLAYER}'
reject_line "$darktableconfig_xml" '@DARKTABLECONFIG_IOP_ENTRIES@'
