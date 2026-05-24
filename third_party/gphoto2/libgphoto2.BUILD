load("@rules_cc//cc:defs.bzl", "cc_binary", "cc_library")

package(default_visibility = ["//visibility:public"])

COMMON_COPTS = [
    "-D_GPHOTO2_INTERNAL_CODE",
    "-Wno-deprecated-declarations",
    "-Wno-discarded-qualifiers",
    "-Wno-format-truncation",
    "-Wno-implicit-fallthrough",
    "-Wno-maybe-uninitialized",
    "-Wno-missing-field-initializers",
    "-Wno-pointer-sign",
    "-Wno-shadow",
    "-Wno-sign-compare",
    "-Wno-stringop-truncation",
    "-Wno-unused-function",
    "-Wno-unused-parameter",
    "-Wno-unused-variable",
]

GPHOTO2_CONFIG_COPTS = COMMON_COPTS + [
    "-include",
    "bazel/config/config.h",
]

PORT_CONFIG_COPTS = COMMON_COPTS + [
    "-include",
    "bazel/port_config/config.h",
]

GPHOTO2_INCLUDES = [
    "bazel/config",
    ".",
    "libgphoto2_port",
]

PORT_INCLUDES = [
    "bazel/port_config",
    "libgphoto2_port",
]

cc_library(
    name = "ltdl_system",
    linkopts = ["-lltdl"],
)

cc_library(
    name = "gphoto2_port",
    srcs = [
        "libgphoto2_port/libgphoto2_port/gphoto2-port-info-list.c",
        "libgphoto2_port/libgphoto2_port/gphoto2-port-locking.c",
        "libgphoto2_port/libgphoto2_port/gphoto2-port-log.c",
        "libgphoto2_port/libgphoto2_port/gphoto2-port-portability.c",
        "libgphoto2_port/libgphoto2_port/gphoto2-port-result.c",
        "libgphoto2_port/libgphoto2_port/gphoto2-port-version.c",
        "libgphoto2_port/libgphoto2_port/gphoto2-port.c",
    ],
    hdrs = glob([
        "libgphoto2_port/gphoto2/*.h",
        "libgphoto2_port/libgphoto2_port/*.h",
    ]) + [
        "bazel/port_config/config.h",
    ],
    copts = PORT_CONFIG_COPTS,
    includes = PORT_INCLUDES,
    deps = [":ltdl_system"],
)

cc_library(
    name = "gphoto2",
    srcs = [
        "libgphoto2/ahd_bayer.c",
        "libgphoto2/bayer.c",
        "libgphoto2/exif.c",
        "libgphoto2/gamma.c",
        "libgphoto2/gphoto2-abilities-list.c",
        "libgphoto2/gphoto2-camera.c",
        "libgphoto2/gphoto2-context.c",
        "libgphoto2/gphoto2-file.c",
        "libgphoto2/gphoto2-filesys.c",
        "libgphoto2/gphoto2-list.c",
        "libgphoto2/gphoto2-result.c",
        "libgphoto2/gphoto2-setting.c",
        "libgphoto2/gphoto2-version.c",
        "libgphoto2/gphoto2-widget.c",
        "libgphoto2/jpeg.c",
    ],
    hdrs = glob([
        "gphoto2/*.h",
        "libgphoto2/*.h",
    ]) + [
        "bazel/config/config.h",
    ],
    copts = GPHOTO2_CONFIG_COPTS,
    includes = GPHOTO2_INCLUDES,
    linkopts = ["-lm"],
    deps = [
        ":gphoto2_port",
        ":ltdl_system",
        "@libjpeg_turbo//:jpeg",
    ],
)

cc_binary(
    name = "disk.so",
    srcs = ["libgphoto2_port/disk/disk.c"],
    copts = PORT_CONFIG_COPTS,
    includes = PORT_INCLUDES,
    linkshared = True,
    deps = [":gphoto2_port"],
)

cc_binary(
    name = "ptpip.so",
    srcs = ["libgphoto2_port/ptpip/ptpip.c"],
    copts = PORT_CONFIG_COPTS,
    includes = PORT_INCLUDES,
    linkshared = True,
    deps = [":gphoto2_port"],
)

cc_binary(
    name = "serial.so",
    srcs = ["libgphoto2_port/serial/unix.c"],
    copts = PORT_CONFIG_COPTS,
    includes = PORT_INCLUDES,
    linkshared = True,
    deps = [":gphoto2_port"],
)

cc_binary(
    name = "usb1.so",
    srcs = ["libgphoto2_port/libusb1/libusb1.c"],
    copts = PORT_CONFIG_COPTS,
    includes = PORT_INCLUDES,
    linkshared = True,
    deps = [
        ":gphoto2_port",
        "@libusb//:libusb",
    ],
)

CAMLIB_DEPS = [
    ":gphoto2",
    ":gphoto2_port",
    "@libjpeg_turbo//:jpeg",
    "@libxml2//:xml2",
]

cc_binary(
    name = "directory.so",
    srcs = ["camlibs/directory/directory.c"] + glob(["camlibs/directory/*.h"], allow_empty = True),
    copts = GPHOTO2_CONFIG_COPTS,
    includes = GPHOTO2_INCLUDES + ["camlibs"],
    linkshared = True,
    deps = CAMLIB_DEPS,
)

cc_binary(
    name = "ptp2.so",
    additional_compiler_inputs = ["camlibs/ptp2/ptp-pack.c"],
    srcs = [
        "camlibs/ptp2/chdk.c",
        "camlibs/ptp2/config.c",
        "camlibs/ptp2/fujiptpip.c",
        "camlibs/ptp2/library.c",
        "camlibs/ptp2/olympus-wrap.c",
        "camlibs/ptp2/ptp-pack.c",
        "camlibs/ptp2/ptp.c",
        "camlibs/ptp2/ptpip.c",
        "camlibs/ptp2/usb.c",
    ] + glob(["camlibs/ptp2/*.h"]),
    copts = GPHOTO2_CONFIG_COPTS,
    includes = GPHOTO2_INCLUDES + ["camlibs", "camlibs/ptp2"],
    linkshared = True,
    deps = CAMLIB_DEPS,
)

filegroup(
    name = "runtime_modules",
    srcs = [
        ":directory.so",
        ":disk.so",
        ":ptp2.so",
        ":ptpip.so",
        ":serial.so",
        ":usb1.so",
    ],
)
