def darktable_config(name = "config.h"):
    native.genrule(
        name = "generate_config_h",
        outs = [name],
        cmd = """cat > "$@" <<'EOF'
#pragma once
#include <stddef.h>

#define PACKAGE_NAME "darktable"
#define PACKAGE_BUGREPORT "https://github.com/darktable-org/darktable/issues/new/choose"
#define PACKAGE_DOCS "https://www.darktable.org/resources/"

extern const char darktable_package_version[];
extern const char darktable_package_string[];
extern const char darktable_last_commit_year[];

static const char *dt_supported_extensions[] __attribute__((unused)) = {"3fr", "ari", "arw", "avif", "bay", "bmq", "cap", "cine", "cr2", "cr3", "crw", "cs1", "dc2", "dcr", "dng", "erf", "exr", "fff", "heic", "heif", "hif", "ia", "iiq", "j2c", "j2k", "jpeg", "jpg", "jxl", "k25", "kc2", "kdc", "mdc", "mef", "mos", "mrw", "nef", "nrw", "orf", "ori", "pef", "png", "qoi", "raf", "raw", "rdc", "rw2", "rwl", "sr2", "srf", "srw", "tif", "tiff", "webp", "x3f", NULL};

#define GETTEXT_PACKAGE "darktable"
#define DARKTABLE_LOCALEDIR "../share/locale"
#define DARKTABLE_LIBDIR "../lib/darktable"
#define DARKTABLE_DATADIR "../share/darktable"
#define DARKTABLE_SHAREDIR "../share"
#define SHARED_MODULE_PREFIX "lib"
#define SHARED_MODULE_SUFFIX ".so"
#define WANTED_STACK_SIZE (2048 * 1024)
#define WANTED_THREADS_STACK_SIZE (2048 * 1024)
#define ISO_CODES_LOCATION "/usr/share/iso-codes/json"
#define ISO_CODES_LOCALEDIR "/usr/share/locale"

#ifndef __GNUC_PREREQ
#if defined __GNUC__ && defined __GNUC_MINOR__
#define __GNUC_PREREQ(maj, min) ((__GNUC__ << 16) + __GNUC_MINOR__ >= ((maj) << 16) + (min))
#else
#define __GNUC_PREREQ(maj, min) 0
#endif
#endif

#if defined(_OPENMP) && __GNUC_PREREQ(4, 9)
#define OPENMP_SIMD_
#define SIMD() simd
#else
#define SIMD()
#endif

#ifndef __has_feature
#define __has_feature(x) 0
#endif
#ifndef __has_extension
#define __has_extension __has_feature
#endif

#if __has_feature(address_sanitizer) || defined(__SANITIZE_ADDRESS__)
#include <sanitizer/asan_interface.h>
#else
#define ASAN_POISON_MEMORY_REGION(addr, size) ((void)(addr), (void)(size))
#define ASAN_UNPOISON_MEMORY_REGION(addr, size) ((void)(addr), (void)(size))
#endif

#define HAVE_CPUID_H 1
#define HAVE___GET_CPUID 1
#define HAVE_OMP_FIRSTPRIVATE_WITH_CONST 1
#define CL_TARGET_OPENCL_VERSION 300
EOF
""",
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
        cmd = "cp $(location //data:darktableconfig_dtd) $(location darktableconfig.dtd) && sed -e 's/$${DEFCONFIG_APPLE}/false/g' -e 's/$${DEFCONFIG_NONAPPLE}/true/g' -e 's/$${DEFCONFIG_OPENCL}/true/g' -e 's/$${DEFCONFIG_AUDIOPLAYER}/aplay/g' -e 's|@DARKTABLECONFIG_IOP_ENTRIES@||g' $(location //data:darktableconfig_xml_in) > $(location darktableconfig.xml)",
    )

    native.genrule(
        name = "preferences_gen_h",
        srcs = ["//tools:generate_prefs_xsl", ":darktableconfig.xml"],
        outs = ["preferences_gen.h"],
        cmd = "xsltproc --nonet --stringparam HAVE_OPENCL 1 $(location //tools:generate_prefs_xsl) $(location :darktableconfig.xml) > $@",
    )

    native.genrule(
        name = "conf_gen_h",
        srcs = ["//tools:generate_darktablerc_conf_xsl", ":darktableconfig.xml"],
        outs = ["conf_gen.h"],
        cmd = "xsltproc --nonet --stringparam HAVE_OPENCL 1 $(location //tools:generate_darktablerc_conf_xsl) $(location :darktableconfig.xml) > $@",
    )

    native.genrule(
        name = "styles_string_h",
        srcs = ["//data:runtime_data", "//tools:generate_styles_string"],
        outs = ["styles_string.h"],
        cmd = "bash $(location //tools:generate_styles_string) data/styles $@",
    )
