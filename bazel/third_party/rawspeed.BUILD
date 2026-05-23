load("@rules_cc//cc:defs.bzl", "cc_library")

package(default_visibility = ["//visibility:public"])

filegroup(
    name = "runtime_data",
    srcs = [
        "data/cameras.xml",
        "data/showcameras.xsl",
    ],
)

genrule(
    name = "rawspeed_config_h",
    outs = ["rawspeedconfig.h"],
    cmd = """cat > "$@" <<'EOF'
#pragma once
#if defined(__SSE2__)
#define WITH_SSE2 1
#endif
static constexpr unsigned long long RAWSPEED_CACHELINESIZE = 64;
static constexpr unsigned long long RAWSPEED_PAGESIZE = 4096;
static constexpr unsigned long long RAWSPEED_LARGEPAGESIZE = 4096;
#define HAVE_PUGIXML 1
#define HAVE_OPENMP 1
#define HAVE_ZLIB 1
#define HAVE_JPEG 1
#define HAVE_JPEG_MEM_SRC 1
#define HAVE_CXX_THREAD_LOCAL 1
#define RAWSPEED_UNLIKELY_FUNCTION __attribute__((cold))
#define RAWSPEED_NOINLINE __attribute__((noinline))
#define RAWSPEED_READONLY __attribute__((pure))
#define RAWSPEED_READNONE __attribute__((const))
#ifndef __has_feature
#define __has_feature(x) 0
#endif
#ifndef __has_extension
#define __has_extension __has_feature
#endif
EOF
""",
)

cc_library(
    name = "rawspeed",
    srcs = glob(["src/librawspeed/**/*.cpp"]),
    hdrs = glob([
        "src/external/**",
        "src/librawspeed/**/*.h",
    ]) + [":rawspeedconfig.h"],
    copts = [
        "-w",
        "-Wno-error",
    ],
    includes = [
        ".",
        "src",
        "src/librawspeed",
        "src/external",
    ],
    linkopts = [
        "-ljpeg",
        "-lz",
        "-lm",
    ],
    deps = ["@darktable_linux_system_probe//:pkg"],
)
