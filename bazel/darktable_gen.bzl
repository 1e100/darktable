load(
    "//bazel:darktable_features.bzl",
    "LINUX",
    "config_h_content",
    "darktableconfig_substitutions",
    "have_opencl_value",
)

def _write_file_cmd(content):
    return "cat > \"$@\" <<'EOF'\n%sEOF\n" % content

def _unsupported_platform_cmd(output):
    return "echo 'unsupported darktable Bazel target platform for %s' >&2; exit 1" % output

def _platform_select(linux_value, output):
    return select({
        "//bazel/config:target_linux": linux_value,
        "//conditions:default": _unsupported_platform_cmd(output),
    })

def _sed_expr(pattern, replacement):
    return "-e 's|%s|%s|g'" % (pattern, replacement)

def _darktableconfig_cmd(platform):
    substitutions = darktableconfig_substitutions(platform)
    sed_args = [
        _sed_expr("$${DEFCONFIG_APPLE}", substitutions["DEFCONFIG_APPLE"]),
        _sed_expr("$${DEFCONFIG_NONAPPLE}", substitutions["DEFCONFIG_NONAPPLE"]),
        _sed_expr("$${DEFCONFIG_OPENCL}", substitutions["DEFCONFIG_OPENCL"]),
        _sed_expr("$${DEFCONFIG_AUDIOPLAYER}", substitutions["DEFCONFIG_AUDIOPLAYER"]),
        _sed_expr("@DARKTABLECONFIG_IOP_ENTRIES@", substitutions["DARKTABLECONFIG_IOP_ENTRIES"]),
    ]
    return "cp $(location //data:darktableconfig_dtd) $(location darktableconfig.dtd) && sed %s $(location //data:darktableconfig_xml_in) > $(location darktableconfig.xml)" % " ".join(sed_args)

def darktable_config(name = "config.h"):
    native.genrule(
        name = "generate_config_h",
        outs = [name],
        cmd = _platform_select(_write_file_cmd(config_h_content(LINUX)), name),
    )

def darktable_generated_headers():
    darktable_config()

    native.genrule(
        name = "version_gen",
        srcs = [
            "//tools:create_version_c",
            "//tools:create_version_c_script",
        ],
        outs = ["version_gen.c"],
        cmd = "bash $(location //tools:create_version_c_script) $@ 5.4.1",
    )

    native.genrule(
        name = "authors_h",
        srcs = ["//tools:authors_h", "//:AUTHORS"],
        outs = ["tools/darktable_authors.h"],
        cmd = "mkdir -p $(@D) && bash $(location //tools:authors_h) $(location //:AUTHORS) $@",
    )

    native.genrule(
        name = "darktableconfig_xml",
        srcs = [
            "//data:darktableconfig_dtd",
            "//data:darktableconfig_xml_in",
        ],
        outs = [
            "darktableconfig.dtd",
            "darktableconfig.xml",
        ],
        cmd = _platform_select(_darktableconfig_cmd(LINUX), "darktableconfig.xml"),
    )

    native.genrule(
        name = "preferences_gen_h",
        srcs = ["//tools:generate_prefs_xsl", ":darktableconfig.xml"],
        outs = ["preferences_gen.h"],
        cmd = _platform_select(
            "xsltproc --nonet --stringparam HAVE_OPENCL %s $(location //tools:generate_prefs_xsl) $(location :darktableconfig.xml) > $@" % have_opencl_value(LINUX),
            "preferences_gen.h",
        ),
    )

    native.genrule(
        name = "conf_gen_h",
        srcs = ["//tools:generate_darktablerc_conf_xsl", ":darktableconfig.xml"],
        outs = ["conf_gen.h"],
        cmd = _platform_select(
            "xsltproc --nonet --stringparam HAVE_OPENCL %s $(location //tools:generate_darktablerc_conf_xsl) $(location :darktableconfig.xml) > $@" % have_opencl_value(LINUX),
            "conf_gen.h",
        ),
    )

    native.genrule(
        name = "generate_darktablerc",
        srcs = [
            "//tools:generate_darktablerc_xsl",
            ":darktableconfig.dtd",
            ":darktableconfig.xml",
        ],
        outs = ["darktablerc"],
        cmd = "xsltproc --nonet $(location //tools:generate_darktablerc_xsl) $(location :darktableconfig.xml) > $@",
    )

    native.genrule(
        name = "styles_string_h",
        srcs = ["//data:runtime_data", "//tools:generate_styles_string"],
        outs = ["styles_string.h"],
        cmd = "bash $(location //tools:generate_styles_string) data/styles $@",
    )
