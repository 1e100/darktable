def _runtime_tree_impl(ctx):
    out = ctx.actions.declare_directory(ctx.attr.dirname)
    runtime_files = []
    seen_runtime_files = {}

    for target in ctx.attr.srcs:
        if DefaultInfo in target:
            for file in target[DefaultInfo].default_runfiles.files.to_list():
                if file.path not in seen_runtime_files:
                    seen_runtime_files[file.path] = True
                    runtime_files.append(file)

    commands = [
        "set -eu",
        "root='%s'" % out.path,
        "rm -rf \"$root\"",
        "mkdir -p \"$root\"",
        "mkdir -p \"$root/share/locale\"",
        "touch \"$root/share/locale/.keep\"",
    ]

    for src, dest in zip(ctx.files.srcs, ctx.attr.dests):
        commands.append("mkdir -p \"$root/%s\"" % dest.rpartition("/")[0])
        commands.append("cp -L '%s' \"$root/%s\"" % (src.path, dest))

    for src in runtime_files:
        parts = src.short_path.split("/")
        solib_index = -1
        for index, part in enumerate(parts):
            if part.startswith("_solib_"):
                solib_index = index
                break
        if solib_index < 0:
            continue
        dest = "lib/darktable/bazel-solib/" + "/".join(parts[solib_index + 1:])
        if dest.endswith("/libdarktable.so"):
            continue
        commands.append("mkdir -p \"$root/%s\"" % dest.rpartition("/")[0])
        commands.append("cp -L '%s' \"$root/%s\"" % (src.path, dest))

    for src in ctx.files.data:
        short_path = src.short_path
        if short_path.startswith("../"):
            continue
        if not short_path.startswith(ctx.attr.data_strip_prefix):
            fail("runtime data file %s does not start with %s" % (short_path, ctx.attr.data_strip_prefix))
        dest = ctx.attr.data_dest_prefix + short_path[len(ctx.attr.data_strip_prefix):]
        commands.append("mkdir -p \"$root/%s\"" % dest.rpartition("/")[0])
        commands.append("cp -L '%s' \"$root/%s\"" % (src.path, dest))

    commands.extend([
        "cat > \"$root/bin/darktable-bazel\" <<'EOF'",
        "#!/bin/sh",
        "set -eu",
        "self=$(CDPATH= cd -- \"$(dirname -- \"$0\")\" && pwd)",
        "root=$(CDPATH= cd -- \"$self/..\" && pwd)",
        "if [ -d \"$root/share/darktable/icu\" ]; then",
        "  export ICU_DATA=\"$root/share/darktable/icu\"",
        "fi",
        "if [ -d \"$root/lib/darktable/libgphoto2\" ]; then",
        "  export CAMLIBS=\"$root/lib/darktable/libgphoto2/2.5.33\"",
        "fi",
        "if [ -d \"$root/lib/darktable/libgphoto2_port\" ]; then",
        "  export IOLIBS=\"$root/lib/darktable/libgphoto2_port/0.12.2\"",
        "fi",
        "exec \"$root/bin/darktable\" --moduledir \"$root/lib/darktable\" --datadir \"$root/share/darktable\" --localedir \"$root/share/locale\" \"$@\"",
        "EOF",
        "chmod +x \"$root/bin/darktable-bazel\"",
    ])

    ctx.actions.run_shell(
        inputs = ctx.files.srcs + ctx.files.data + runtime_files,
        outputs = [out],
        command = "\n".join(commands),
        mnemonic = "DarktableRuntimeTree",
        progress_message = "Assembling darktable Bazel runtime tree",
    )

    return [DefaultInfo(files = depset([out]))]

runtime_tree = rule(
    implementation = _runtime_tree_impl,
    attrs = {
        "data": attr.label_list(allow_files = True),
        "data_dest_prefix": attr.string(default = "share/darktable/"),
        "data_strip_prefix": attr.string(default = "data/"),
        "dests": attr.string_list(mandatory = True),
        "dirname": attr.string(default = "darktable-runtime"),
        "srcs": attr.label_list(allow_files = True, mandatory = True),
    },
)

def dt_runtime_tree(name, entries, data = [], dirname = "darktable-runtime", target_compatible_with = []):
    runtime_tree(
        name = name,
        srcs = [entry[0] for entry in entries],
        dests = [entry[1] for entry in entries],
        data = data,
        dirname = dirname,
        target_compatible_with = target_compatible_with,
    )
