load("@rules_cc//cc:defs.bzl", "cc_library")

package(default_visibility = ["//visibility:public"])

cc_library(
    name = "lautoc",
    srcs = ["lautoc.c"],
    hdrs = [
        "lautoc.h",
        "lautocall.h",
    ],
    includes = ["."],
    deps = ["@lua_internal//:lua"],
)
