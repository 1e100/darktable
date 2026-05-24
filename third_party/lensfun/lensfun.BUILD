load("@rules_cc//cc:defs.bzl", "cc_library")

package(default_visibility = ["//visibility:public"])

LENSFUN_DB_FILES = [
    "6x6.xml",
    "actioncams.xml",
    "compact-canon.xml",
    "compact-casio.xml",
    "compact-fujifilm.xml",
    "compact-kodak.xml",
    "compact-konica-minolta.xml",
    "compact-leica.xml",
    "compact-nikon.xml",
    "compact-olympus.xml",
    "compact-panasonic.xml",
    "compact-pentax.xml",
    "compact-ricoh.xml",
    "compact-samsung.xml",
    "compact-sigma.xml",
    "compact-sony.xml",
    "contax.xml",
    "generic.xml",
    "mil-canon.xml",
    "mil-fujifilm.xml",
    "mil-leica.xml",
    "mil-nikon.xml",
    "mil-olympus.xml",
    "mil-panasonic.xml",
    "mil-pentax.xml",
    "mil-samsung.xml",
    "mil-samyang.xml",
    "mil-sigma.xml",
    "mil-sony.xml",
    "mil-tamron.xml",
    "mil-tokina.xml",
    "mil-zeiss.xml",
    "misc.xml",
    "om-system.xml",
    "rf-leica.xml",
    "slr-canon.xml",
    "slr-hasselblad.xml",
    "slr-konica-minolta.xml",
    "slr-leica.xml",
    "slr-nikon.xml",
    "slr-olympus.xml",
    "slr-panasonic.xml",
    "slr-pentax.xml",
    "slr-ricoh.xml",
    "slr-samsung.xml",
    "slr-samyang.xml",
    "slr-schneider.xml",
    "slr-sigma.xml",
    "slr-soligor.xml",
    "slr-sony.xml",
    "slr-tamron.xml",
    "slr-tokina.xml",
    "slr-ussr.xml",
    "slr-vivitar.xml",
    "slr-zeiss.xml",
    "timestamp.txt",
]

exports_files(["data/db/" + f for f in LENSFUN_DB_FILES])

genrule(
    name = "generate_config_h",
    srcs = ["include/lensfun/config.h.in.cmake"],
    outs = ["libs/lensfun/config.h"],
    cmd = "sed " +
          "-e 's/@VERSION_MAJOR@/0/g' " +
          "-e 's/@VERSION_MINOR@/3/g' " +
          "-e 's/@VERSION_MICRO@/4/g' " +
          "-e 's/@VERSION_BUGFIX@/0/g' " +
          "-e 's/#cmakedefine CMAKE_COMPILER_IS_GNUCC.*/#define CMAKE_COMPILER_IS_GNUCC 1/g' " +
          "-e 's/#cmakedefine HAVE_ENDIAN_H.*/#define HAVE_ENDIAN_H 1/g' " +
          "-e 's/#cmakedefine VECTORIZATION_SSE.*/#define VECTORIZATION_SSE 1/g' " +
          "-e 's/#cmakedefine VECTORIZATION_SSE2.*/#define VECTORIZATION_SSE2 1/g' " +
          "-e 's/#cmakedefine PLATFORM_WINDOWS.*/\\/\\* #undef PLATFORM_WINDOWS \\*\\//g' " +
          "-e 's|$${CMAKE_INSTALL_FULL_DATAROOTDIR}|/__darktable_bazel_no_system_lensfun__|g' " +
          "-e 's|$${CMAKE_INSTALL_LOCALSTATEDIR}|/__darktable_bazel_no_system_lensfun_updates__|g' " +
          "-e 's/$${LENSFUN_DB_VERSION}/1/g' " +
          "-e 's/$${LENSFUN_GLIB_REQUIREMENT_MACRO}/GLIB_VERSION_2_26/g' " +
          "$< > $@",
)

genrule(
    name = "generate_lensfun_h",
    srcs = ["include/lensfun/lensfun.h.in"],
    outs = ["libs/lensfun/lensfun.h"],
    cmd = "sed " +
          "-e 's/@VERSION_MAJOR@/0/g' " +
          "-e 's/@VERSION_MINOR@/3/g' " +
          "-e 's/@VERSION_MICRO@/4/g' " +
          "-e 's/@VERSION_BUGFIX@/0/g' " +
          "$< > $@",
)

filegroup(
    name = "lensfun_data",
    srcs = ["data/db/" + f for f in LENSFUN_DB_FILES],
)

cc_library(
    name = "lensfun",
    srcs = [
        "libs/lensfun/auxfun.cpp",
        "libs/lensfun/camera.cpp",
        "libs/lensfun/cpuid.cpp",
        "libs/lensfun/database.cpp",
        "libs/lensfun/lens.cpp",
        "libs/lensfun/lensfunprv.h",
        "libs/lensfun/mod-color-sse.cpp",
        "libs/lensfun/mod-color-sse2.cpp",
        "libs/lensfun/mod-color.cpp",
        "libs/lensfun/mod-coord-sse.cpp",
        "libs/lensfun/mod-coord.cpp",
        "libs/lensfun/mod-subpix.cpp",
        "libs/lensfun/modifier.cpp",
        "libs/lensfun/mount.cpp",
    ],
    hdrs = [
        ":libs/lensfun/config.h",
        ":libs/lensfun/lensfun.h",
        "libs/lensfun/windows/mathconstants.h",
    ],
    copts = [
        "-msse",
        "-msse2",
    ],
    defines = ["CONF_LENSFUN_STATIC"],
    includes = ["libs/lensfun"],
    deps = ["@gtk_stack//:pkg"],
)
