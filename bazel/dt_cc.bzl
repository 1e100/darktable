load("@rules_cc//cc:defs.bzl", "cc_binary", "cc_library")

def _plugin_target_name(name, output_name):
    if output_name:
        return "lib%s.so" % output_name
    return "lib%s.so" % name

def dt_module(name, srcs, deps = [], copts = [], linkopts = [], includes = [], output_name = None):
    cc_binary(
        name = _plugin_target_name(name, output_name),
        srcs = srcs,
        deps = deps,
        copts = copts,
        includes = includes,
        linkopts = linkopts + [
            "-shared",
            "-Wl,--unresolved-symbols=ignore-in-shared-libs",
            "-Wl,--allow-shlib-undefined",
        ],
        linkshared = True,
        linkstatic = False,
        features = ["-fully_static_link"],
        stamp = 0,
    )

def dt_filegroup_modules(name, modules):
    native.filegroup(
        name = name,
        srcs = [":lib%s.so" % module for module in modules],
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

def dt_plugin_module(
        name,
        srcs,
        deps,
        copts,
        includes,
        output_name = None,
        linkopts = [],
        textual_hdrs = []):
    cc_library(
        name = "%s_plugin_objects" % name,
        srcs = srcs,
        textual_hdrs = textual_hdrs,
        copts = copts,
        includes = includes,
        alwayslink = True,
        deps = deps,
    )

    cc_binary(
        name = _plugin_target_name(name, output_name),
        srcs = [],
        deps = [":%s_plugin_objects" % name],
        linkopts = linkopts + [
            "-shared",
            "-Wl,--unresolved-symbols=ignore-in-shared-libs",
            "-Wl,--allow-shlib-undefined",
        ],
        linkshared = True,
        linkstatic = False,
        features = ["-fully_static_link"],
        stamp = 0,
    )

def dt_iop_module(
        name,
        src,
        deps,
        copts,
        includes,
        extra_srcs = [],
        output_name = None,
        linkopts = []):
    generated = "introspection/%s/%s" % (name, src)
    native.genrule(
        name = "generate_iop_introspection_%s" % name,
        srcs = [
            src,
            "//tools:introspection_tools",
        ],
        outs = [generated],
        cmd = "cd tools/introspection && perl parser.pl ../../src/iop ../../$(location %s) ../../$@" % src,
    )

    dt_plugin_module(
        name = name,
        srcs = [":" + generated] + extra_srcs,
        textual_hdrs = [src],
        deps = deps,
        copts = copts + [
            "-include",
            "iop/iop_api.h",
        ],
        includes = includes,
        output_name = output_name,
        linkopts = linkopts,
    )

def _module_extra_deps(module, index):
    if len(module) > index:
        return module[index]
    return []

def _linux_full_select(values):
    if values:
        return select({
            "//src:linux_full": values,
            "//conditions:default": [],
        })
    return []

def dt_iop_modules(modules, deps, copts, includes, linkopts = []):
    for module in modules:
        dt_iop_module(
            name = module[0],
            src = module[1],
            extra_srcs = module[2] + _linux_full_select(_module_extra_deps(module, 4)),
            deps = deps + _module_extra_deps(module, 3) + _linux_full_select(_module_extra_deps(module, 5)),
            copts = copts,
            includes = includes,
            linkopts = linkopts,
        )

def dt_plugin_modules(modules, deps, copts, includes, linkopts = []):
    for module in modules:
        dt_plugin_module(
            name = module[0],
            srcs = module[1],
            deps = deps + _module_extra_deps(module, 2),
            copts = copts,
            includes = includes,
            linkopts = linkopts,
        )

def dt_output_plugin_modules(modules, deps, copts, includes, linkopts = []):
    for module in modules:
        dt_plugin_module(
            name = module[0],
            output_name = module[1],
            srcs = module[2],
            deps = deps + module[3],
            copts = copts,
            includes = includes,
            linkopts = linkopts,
        )

def dt_plugin_group(name, modules, linux_full_modules = []):
    native.filegroup(
        name = name,
        srcs = [":lib%s.so" % module for module in modules] + _linux_full_select(
            [":lib%s.so" % module for module in linux_full_modules],
        ),
    )

def dt_plugin_runtime_layout(name, modules, destdir, linux_full_modules = []):
    layout_targets = []

    for module in modules + linux_full_modules:
        copy_name = "%s_layout_%s" % (name, module)
        native.genrule(
            name = copy_name,
            srcs = [":lib%s.so" % module],
            outs = ["bazel-runtime/lib/darktable/%s/lib%s.so" % (destdir, module)],
            cmd = "cp $(location :lib%s.so) $@" % module,
        )
        layout_targets.append(":" + copy_name)

    native.filegroup(
        name = name,
        srcs = layout_targets[:len(modules)] + _linux_full_select(layout_targets[len(modules):]),
    )
