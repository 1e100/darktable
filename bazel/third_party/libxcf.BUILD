load("@rules_cc//cc:defs.bzl", "cc_library")

package(default_visibility = ["//visibility:public"])

cc_library(
    name = "xcf",
    srcs = [
        "xcf.c",
        "xcf_names.c",
    ],
    hdrs = [
        "xcf.h",
        "xcf_names.h",
    ],
    copts = ["-D_GNU_SOURCE"],
    linkopts = ["-lz", "-lm"],
)
