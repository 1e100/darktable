load("@rules_cc//cc:defs.bzl", "cc_library")

package(default_visibility = ["//visibility:public"])

cc_library(
    name = "xmp",
    srcs = glob(["xmpsdk/src/*.cpp"]),
    hdrs = glob([
        "xmpsdk/include/**/*.h",
        "xmpsdk/include/**/*.hpp",
        "xmpsdk/include/**/*.incl_cpp",
        "xmpsdk/src/**/*.h",
        "xmpsdk/src/**/*.hpp",
        "xmpsdk/src/**/*.incl_cpp",
    ]),
    defines = ["BanAllEntityUsage=1"],
    includes = [
        "xmpsdk/include",
        "xmpsdk/src",
    ],
    deps = ["@libexpat//:libexpat"],
)

cc_library(
    name = "exiv2",
    srcs = glob(["src/*.cpp"]),
    hdrs = glob([
        "include/exiv2/*.h",
        "include/exiv2/*.hpp",
        "src/*.h",
        "src/*.hpp",
    ]),
    defines = [
        "EXIV2API=",
    ],
    includes = [
        "include",
        "include/exiv2",
        "src",
        "xmpsdk/include",
    ],
    deps = [
        ":xmp",
        "@brotli//:brotlidec",
        "@libexpat//:libexpat",
        "@zlib//:zlib",
    ],
)
