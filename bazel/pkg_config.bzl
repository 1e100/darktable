def _shell_join(args):
    return " ".join(["'%s'" % a.replace("'", "'\\''") for a in args])

def _pkg_config_repository_impl(ctx):
    if not ctx.attr.packages:
        fail("packages must not be empty")

    cmd = ["pkg-config", "--cflags", "--libs"] + list(ctx.attr.packages)
    result = ctx.execute(cmd)
    if result.return_code != 0:
        fail("pkg-config failed for %s\n%s" % (_shell_join(ctx.attr.packages), result.stderr))

    tokens = [token for token in result.stdout.replace("\n", " ").split(" ") if token]
    copts = []
    includes = []
    linkopts = []
    include_index = 0
    for token in tokens:
        if token.startswith("-I"):
            include_index += 1
            include_name = "include_%d" % include_index
            ctx.symlink(token[2:], include_name)
            includes.append(include_name)
        elif token.startswith("-D") or token.startswith("-pthread"):
            copts.append(token)
            if token == "-pthread":
                linkopts.append(token)
        elif token.startswith("-Wl,") or token.startswith("-L") or token.startswith("-l") or token.startswith("-framework"):
            linkopts.append(token)
        else:
            copts.append(token)

    ctx.file("BUILD.bazel", """\
load("@rules_cc//cc:defs.bzl", "cc_library")

package(default_visibility = ["//visibility:public"])

cc_library(
    name = "pkg",
    copts = {copts},
    hdrs = glob(["include_*/**"], allow_empty = True),
    includes = {includes},
    linkopts = {linkopts},
)
""".format(copts = repr(copts), includes = repr(includes), linkopts = repr(linkopts)))

pkg_config_repository = repository_rule(
    implementation = _pkg_config_repository_impl,
    attrs = {
        "packages": attr.string_list(mandatory = True),
    },
    local = True,
)

def _system_library_repository_impl(ctx):
    if not ctx.attr.linkopts:
        fail("linkopts must not be empty")

    for path in ctx.attr.include_paths:
        source = ctx.path(path)
        if not source.exists:
            if ctx.attr.required:
                fail("required system include path does not exist: %s" % path)
            continue

        dest = "include/%s" % source.basename
        ctx.symlink(source, dest)

    ctx.file("include/.keep", "")

    ctx.file("BUILD.bazel", """\
load("@rules_cc//cc:defs.bzl", "cc_library")

package(default_visibility = ["//visibility:public"])

cc_library(
    name = "pkg",
    copts = {copts},
    hdrs = glob(["include/**"], allow_empty = True),
    includes = ["include"],
    linkopts = {linkopts},
)
""".format(copts = repr(ctx.attr.copts), linkopts = repr(ctx.attr.linkopts)))

system_library_repository = repository_rule(
    implementation = _system_library_repository_impl,
    attrs = {
        "copts": attr.string_list(),
        "include_paths": attr.string_list(),
        "linkopts": attr.string_list(mandatory = True),
        "required": attr.bool(default = True),
    },
    local = True,
)

def _first_existing(ctx, paths):
    for path in paths:
        if not path:
            continue
        candidate = ctx.path(path)
        if candidate.exists:
            return candidate
    return None

def _onnxruntime_system_repository_impl(ctx):
    include_env = ctx.os.environ.get("ONNXRUNTIME_INCLUDE_DIR", "")
    library_env = ctx.os.environ.get("ONNXRUNTIME_LIBRARY", "")

    include_candidates = []
    if include_env:
        include_candidates.extend([
            "%s/onnxruntime_c_api.h" % include_env,
            "%s/onnxruntime/core/session/onnxruntime_c_api.h" % include_env,
        ])
    include_candidates.extend([
        "/usr/include/onnxruntime_c_api.h",
        "/usr/include/onnxruntime/onnxruntime_c_api.h",
        "/usr/include/onnxruntime/core/session/onnxruntime_c_api.h",
        "/usr/local/include/onnxruntime_c_api.h",
        "/usr/local/include/onnxruntime/onnxruntime_c_api.h",
        "/usr/local/include/onnxruntime/core/session/onnxruntime_c_api.h",
        "/opt/onnxruntime/include/onnxruntime_c_api.h",
    ])

    header = _first_existing(ctx, include_candidates)
    if not header:
        if ctx.attr.required:
            fail("ONNXRuntime header not found; set ONNXRUNTIME_INCLUDE_DIR to the directory containing onnxruntime_c_api.h")
        ctx.file("include/onnxruntime_c_api.h", """\
#error "ONNXRuntime header not found; set ONNXRUNTIME_INCLUDE_DIR to the directory containing onnxruntime_c_api.h"
""")
    elif header.basename == "onnxruntime_c_api.h":
        ctx.symlink(header, "include/onnxruntime_c_api.h")
    else:
        fail("ONNXRUNTIME_INCLUDE_DIR must resolve to onnxruntime_c_api.h")

    library_candidates = []
    if library_env:
        library_candidates.append(library_env)
    library_candidates.extend([
        "/usr/lib/libonnxruntime.so",
        "/usr/lib64/libonnxruntime.so",
        "/usr/lib/x86_64-linux-gnu/libonnxruntime.so",
        "/usr/lib/aarch64-linux-gnu/libonnxruntime.so",
        "/usr/local/lib/libonnxruntime.so",
        "/usr/local/lib64/libonnxruntime.so",
        "/opt/onnxruntime/lib/libonnxruntime.so",
    ])

    library = _first_existing(ctx, library_candidates)
    if not library:
        if ctx.attr.required:
            fail("ONNXRuntime library not found; set ONNXRUNTIME_LIBRARY to libonnxruntime.so")
        library_name = "libonnxruntime.so"
        ctx.file("lib/%s" % library_name, "")
    else:
        library_name = library.basename
        ctx.symlink(library, "lib/%s" % library_name)

    ctx.file("BUILD.bazel", """\
load("@rules_cc//cc:defs.bzl", "cc_library")

package(default_visibility = ["//visibility:public"])

cc_library(
    name = "headers",
    hdrs = ["include/onnxruntime_c_api.h"],
    includes = ["include"],
    defines = [
        "ORT_LAZY_LOAD=1",
        "ORT_LIBRARY_PATH=\\\\\\\"{library_name}\\\\\\\"",
    ],
)

filegroup(
    name = "runtime_library",
    srcs = ["lib/{library_name}"],
)
""".format(library_name = library_name))

onnxruntime_system_repository = repository_rule(
    implementation = _onnxruntime_system_repository_impl,
    attrs = {
        "required": attr.bool(default = True),
    },
    environ = [
        "ONNXRUNTIME_INCLUDE_DIR",
        "ONNXRUNTIME_LIBRARY",
    ],
    local = True,
)
