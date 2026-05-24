load("@rules_cc//cc:defs.bzl", "cc_library")

package(default_visibility = ["//visibility:public"])

cc_library(
    name = "lcms2",
    srcs = glob(["src/*.c"]),
    hdrs = glob(["include/*.h"]) + glob(["src/*.h"]),
    copts = ["-UHAVE_CONFIG_H"],
    includes = ["include"],
    linkopts = ["-lm"],
)
