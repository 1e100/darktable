def _install_tree_impl(ctx):
    out = ctx.actions.declare_directory(ctx.attr.dirname)

    commands = [
        "set -eu",
        "root='%s'" % out.path,
        "rm -rf \"$root\"",
        "mkdir -p \"$root/usr\"",
        "cp -a '%s/.' \"$root/usr/\"" % ctx.file.runtime_tree.path,
    ]

    for src, dest in zip(ctx.files.srcs, ctx.attr.dests):
        commands.append("mkdir -p \"$root/%s\"" % dest.rpartition("/")[0])
        commands.append("cp -L '%s' \"$root/%s\"" % (src.path, dest))
        if dest.startswith("usr/bin/") or dest.startswith("usr/libexec/"):
            commands.append("chmod +x \"$root/%s\"" % dest)

    ctx.actions.run_shell(
        inputs = [ctx.file.runtime_tree] + ctx.files.srcs,
        outputs = [out],
        command = "\n".join(commands),
        mnemonic = "DarktableInstallTree",
        progress_message = "Assembling darktable install tree",
    )

    return [DefaultInfo(files = depset([out]))]

install_tree = rule(
    implementation = _install_tree_impl,
    attrs = {
        "dests": attr.string_list(mandatory = True),
        "dirname": attr.string(default = "darktable-install"),
        "runtime_tree": attr.label(allow_single_file = True, mandatory = True),
        "srcs": attr.label_list(allow_files = True),
    },
)

def _install_tar_impl(ctx):
    out = ctx.actions.declare_file(ctx.attr.out)
    ctx.actions.run_shell(
        inputs = [ctx.file.install_tree],
        outputs = [out],
        command = "\n".join([
            "set -eu",
            "tar --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner -C '%s' -cf '%s' ." % (
                ctx.file.install_tree.path,
                out.path,
            ),
        ]),
        mnemonic = "DarktableInstallTar",
        progress_message = "Creating darktable install tar",
    )
    return [DefaultInfo(files = depset([out]))]

install_tar = rule(
    implementation = _install_tar_impl,
    attrs = {
        "install_tree": attr.label(allow_single_file = True, mandatory = True),
        "out": attr.string(mandatory = True),
    },
)
