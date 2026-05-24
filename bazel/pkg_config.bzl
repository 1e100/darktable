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
            fail("required system include path does not exist: %s" % path)

        dest = "include/%s" % source.basename
        ctx.symlink(source, dest)

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
    },
    local = True,
)
