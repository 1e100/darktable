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
