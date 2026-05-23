load("@rules_cc//cc:defs.bzl", "cc_binary", "cc_library")

def dt_module(name, srcs, deps = [], copts = [], linkopts = [], includes = [], output_name = None):
    cc_binary(
        name = name,
        srcs = srcs,
        deps = deps,
        copts = copts,
        includes = includes,
        linkopts = linkopts + [
            "-shared",
            "-Wl,--unresolved-symbols=ignore-in-shared-libs",
        ],
        linkshared = True,
        linkstatic = False,
        features = ["-fully_static_link"],
        stamp = 0,
    )

def dt_filegroup_modules(name, modules):
    native.filegroup(
        name = name,
        srcs = [":" + module for module in modules],
    )

def dt_core_lib(name, srcs, copts, includes, deps, textual_hdrs = []):
    cc_library(
        name = name,
        srcs = srcs,
        textual_hdrs = textual_hdrs,
        copts = copts,
        includes = includes,
        alwayslink = True,
        deps = deps,
    )
