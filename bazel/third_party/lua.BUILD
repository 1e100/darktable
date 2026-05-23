load("@rules_cc//cc:defs.bzl", "cc_library")

package(default_visibility = ["//visibility:public"])

cc_library(
    name = "lua",
    srcs = glob(
        ["src/*.c"],
        exclude = [
            "src/lua.c",
            "src/luac.c",
        ],
    ),
    hdrs = glob(["src/*.h"]) + ["src/lua.hpp"],
    copts = ["-DLUA_COMPAT_5_3"],
    includes = ["src"],
    linkopts = ["-ldl", "-lm"],
)
