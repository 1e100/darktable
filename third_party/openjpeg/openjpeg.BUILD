load("@rules_cc//cc:defs.bzl", "cc_library")

package(default_visibility = ["//visibility:public"])

cc_library(
    name = "openjp2",
    srcs = [
        "src/lib/openjp2/bio.c",
        "src/lib/openjp2/cio.c",
        "src/lib/openjp2/dwt.c",
        "src/lib/openjp2/event.c",
        "src/lib/openjp2/function_list.c",
        "src/lib/openjp2/ht_dec.c",
        "src/lib/openjp2/image.c",
        "src/lib/openjp2/invert.c",
        "src/lib/openjp2/j2k.c",
        "src/lib/openjp2/jp2.c",
        "src/lib/openjp2/mct.c",
        "src/lib/openjp2/mqc.c",
        "src/lib/openjp2/openjpeg.c",
        "src/lib/openjp2/opj_clock.c",
        "src/lib/openjp2/opj_malloc.c",
        "src/lib/openjp2/pi.c",
        "src/lib/openjp2/sparse_array.c",
        "src/lib/openjp2/t1.c",
        "src/lib/openjp2/t2.c",
        "src/lib/openjp2/tcd.c",
        "src/lib/openjp2/tgt.c",
        "src/lib/openjp2/thread.c",
    ],
    hdrs = glob(["src/lib/openjp2/*.h"]),
    copts = [
        "-DOPJ_STATIC",
        "-DMUTEX_pthread",
        "-UHAVE_CONFIG_H",
        "-Wno-unused-function",
    ],
    includes = ["src/lib/openjp2"],
    linkopts = [
        "-lm",
        "-pthread",
    ],
)
