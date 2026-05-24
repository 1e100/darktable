load(
    "//bazel:darktable_features.bzl",
    "linux_config_h_content",
    "linux_have_opencl_value",
)

def darktable_config(name = "config.h"):
    native.genrule(
        name = "generate_config_h",
        outs = [name],
        cmd = "cat > \"$@\" <<'EOF'\n%sEOF\n" % linux_config_h_content(),
    )

def darktable_generated_headers():
    darktable_config()
    have_opencl = linux_have_opencl_value()

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
        cmd = "cp $(location //data:darktableconfig_dtd) $(location darktableconfig.dtd) && sed -e 's/$${DEFCONFIG_APPLE}/false/g' -e 's/$${DEFCONFIG_NONAPPLE}/true/g' -e 's/$${DEFCONFIG_OPENCL}/true/g' -e 's/$${DEFCONFIG_AUDIOPLAYER}/aplay/g' -e 's|@DARKTABLECONFIG_IOP_ENTRIES@||g' $(location //data:darktableconfig_xml_in) > $(location darktableconfig.xml)",
    )

    native.genrule(
        name = "preferences_gen_h",
        srcs = ["//tools:generate_prefs_xsl", ":darktableconfig.xml"],
        outs = ["preferences_gen.h"],
        cmd = "xsltproc --nonet --stringparam HAVE_OPENCL %s $(location //tools:generate_prefs_xsl) $(location :darktableconfig.xml) > $@" % have_opencl,
    )

    native.genrule(
        name = "conf_gen_h",
        srcs = ["//tools:generate_darktablerc_conf_xsl", ":darktableconfig.xml"],
        outs = ["conf_gen.h"],
        cmd = "xsltproc --nonet --stringparam HAVE_OPENCL %s $(location //tools:generate_darktablerc_conf_xsl) $(location :darktableconfig.xml) > $@" % have_opencl,
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
