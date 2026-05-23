load("@rules_cc//cc:defs.bzl", "cc_library")

package(default_visibility = ["//visibility:public"])

genrule(
    name = "libraw_config_h",
    outs = ["libraw/libraw_config.h"],
    cmd = """cat > "$@" <<'EOF'
#ifndef __LIBRAW_CONFIG_H
#define __LIBRAW_CONFIG_H
#define LIBRAW_USE_DNGDEFLATECODEC 1
#define LIBRAW_USE_DNGLOSSYCODEC 1
#define LIBRAW_USE_OPENMP 1
/* darktable's CMake build disables LCMS and Jasper for bundled LibRaw. */
/* #undef LIBRAW_USE_LCMS */
/* #undef LIBRAW_USE_REDCINECODEC */
/* #undef LIBRAW_USE_RAWSPEED */
/* #undef LIBRAW_USE_DCRAW_DEBUG */
/* #undef LIBRAW_USE_X3FTOOLS */
/* #undef LIBRAW_USE_6BY9RPI */
#endif
EOF
""",
)

cc_library(
    name = "libraw",
    srcs = glob(
        ["src/**/*.cpp"],
        exclude = [
            "src/**/*_ph.cpp",
            "src/integration/rawspeed_glue.cpp",
        ],
    ),
    hdrs = glob([
        "internal/**/*.h",
        "libraw/**/*.h",
    ]) + [":libraw/libraw_config.h"],
    copts = [
        "-w",
        "-DLIBRAW_NODLL",
        "-DUSE_ZLIB",
        "-DUSE_JPEG",
        "-DUSE_JPEG8",
    ],
    includes = ["."],
    linkopts = [
        "-ljpeg",
        "-lz",
        "-lm",
    ],
    deps = ["@darktable_linux_system_probe//:pkg"],
)
