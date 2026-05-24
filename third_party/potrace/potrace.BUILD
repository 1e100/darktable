load("@rules_cc//cc:defs.bzl", "cc_library")

cc_library(
    name = "potrace",
    srcs = [
        "src/auxiliary.h",
        "src/bitmap.h",
        "src/bitops.h",
        "src/config.h",
        "src/curve.c",
        "src/curve.h",
        "src/decompose.c",
        "src/decompose.h",
        "src/lists.h",
        "src/platform.h",
        "src/potracelib.c",
        "src/progress.h",
        "src/trace.c",
        "src/trace.h",
    ],
    hdrs = ["src/potracelib.h"],
    includes = ["src"],
    strip_include_prefix = "src",
    visibility = ["//visibility:public"],
)
