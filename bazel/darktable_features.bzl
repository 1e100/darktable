LINUX_FEATURE_DEFINES = {
    "HAVE_CPUID_H": "1",
    "HAVE___GET_CPUID": "1",
    "HAVE_OMP_FIRSTPRIVATE_WITH_CONST": "1",
    "HAVE_OPENCL": "1",
    "HAVE_LIBRAW": "1",
    "USE_LUA": "1",
    "HAVE_GPHOTO2": "1",
    "HAVE_LIBJXL": "1",
    "HAVE_WEBP": "1",
    "HAVE_LIBAVIF": "1",
    "HAVE_LIBHEIF": "1",
    "HAVE_OPENEXR": "1",
    "HAVE_OPENJPEG": "1",
    "HAVE_ICU": "1",
    "HAVE_MAP": "1",
    "HAVE_OSMGPSMAP_110_OR_NEWER": "1",
    "HAVE_OSMGPSMAP_NEWER_THAN_110": "1",
    "USE_COLORDGTK": "1",
    "HAVE_LIBSECRET": "1",
    "HAVE_GMIC": "1",
    "HAVE_PRINT": "1",
}

LINUX_CONFIG_VALUES = {
    "package_name": "darktable",
    "package_bugreport": "https://github.com/darktable-org/darktable/issues/new/choose",
    "package_docs": "https://www.darktable.org/resources/",
    "gettext_package": "darktable",
    "localedir": "../share/locale",
    "libdir": "../lib/darktable",
    "datadir": "../share/darktable",
    "sharedir": "../share",
    "shared_module_prefix": "lib",
    "shared_module_suffix": ".so",
    "wanted_stack_size": "2048 * 1024",
    "wanted_threads_stack_size": "2048 * 1024",
    "iso_codes_location": "/usr/share/iso-codes/json",
    "iso_codes_localedir": "/usr/share/locale",
    "cl_target_opencl_version": "300",
}

BASE_SUPPORTED_EXTENSIONS = [
    "3fr",
    "ari",
    "arw",
    "bay",
    "bmq",
    "cap",
    "cine",
    "cr2",
    "cr3",
    "crw",
    "cs1",
    "dc2",
    "dcr",
    "dng",
    "erf",
    "fff",
    "ia",
    "iiq",
    "jpeg",
    "jpg",
    "k25",
    "kc2",
    "kdc",
    "mdc",
    "mef",
    "mos",
    "mrw",
    "nef",
    "nrw",
    "orf",
    "ori",
    "pef",
    "png",
    "qoi",
    "raf",
    "raw",
    "rdc",
    "rw2",
    "rwl",
    "sr2",
    "srf",
    "srw",
    "tif",
    "tiff",
    "x3f",
]

FEATURE_SUPPORTED_EXTENSIONS = {
    "HAVE_LIBAVIF": ["avif"],
    "HAVE_LIBHEIF": ["heic", "heif", "hif"],
    "HAVE_LIBJXL": ["jxl"],
    "HAVE_OPENEXR": ["exr"],
    "HAVE_OPENJPEG": ["j2c", "j2k"],
    "HAVE_WEBP": ["webp"],
}

def _unique_sorted(values):
    seen = {}
    for value in values:
        seen[value] = True
    return sorted(seen.keys())

def linux_supported_extensions():
    extensions = list(BASE_SUPPORTED_EXTENSIONS)
    for feature, feature_extensions in FEATURE_SUPPORTED_EXTENSIONS.items():
        if feature in LINUX_FEATURE_DEFINES:
            extensions.extend(feature_extensions)
    return _unique_sorted(extensions)

def linux_feature_define_lines():
    lines = []
    for name in sorted(LINUX_FEATURE_DEFINES.keys()):
        lines.append("#define %s %s" % (name, LINUX_FEATURE_DEFINES[name]))
    lines.append("#define CL_TARGET_OPENCL_VERSION %s" % LINUX_CONFIG_VALUES["cl_target_opencl_version"])
    return lines

def linux_have_opencl_value():
    return "1" if "HAVE_OPENCL" in LINUX_FEATURE_DEFINES else "0"

def _c_string(value):
    return "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\""

def linux_config_h_content():
    values = LINUX_CONFIG_VALUES
    extensions = ", ".join([_c_string(extension) for extension in linux_supported_extensions()])
    feature_defines = "\n".join(linux_feature_define_lines())

    return """#pragma once
#include <stddef.h>

#define PACKAGE_NAME {package_name}
#define PACKAGE_BUGREPORT {package_bugreport}
#define PACKAGE_DOCS {package_docs}

extern const char darktable_package_version[];
extern const char darktable_package_string[];
extern const char darktable_last_commit_year[];

static const char *dt_supported_extensions[] __attribute__((unused)) = {{{extensions}, NULL}};

#define GETTEXT_PACKAGE {gettext_package}
#define DARKTABLE_LOCALEDIR {localedir}
#define DARKTABLE_LIBDIR {libdir}
#define DARKTABLE_DATADIR {datadir}
#define DARKTABLE_SHAREDIR {sharedir}
#define SHARED_MODULE_PREFIX {shared_module_prefix}
#define SHARED_MODULE_SUFFIX {shared_module_suffix}
#define WANTED_STACK_SIZE ({wanted_stack_size})
#define WANTED_THREADS_STACK_SIZE ({wanted_threads_stack_size})
#define ISO_CODES_LOCATION {iso_codes_location}
#define ISO_CODES_LOCALEDIR {iso_codes_localedir}

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

{feature_defines}
""".format(
        package_name = _c_string(values["package_name"]),
        package_bugreport = _c_string(values["package_bugreport"]),
        package_docs = _c_string(values["package_docs"]),
        extensions = extensions,
        gettext_package = _c_string(values["gettext_package"]),
        localedir = _c_string(values["localedir"]),
        libdir = _c_string(values["libdir"]),
        datadir = _c_string(values["datadir"]),
        sharedir = _c_string(values["sharedir"]),
        shared_module_prefix = _c_string(values["shared_module_prefix"]),
        shared_module_suffix = _c_string(values["shared_module_suffix"]),
        wanted_stack_size = values["wanted_stack_size"],
        wanted_threads_stack_size = values["wanted_threads_stack_size"],
        iso_codes_location = _c_string(values["iso_codes_location"]),
        iso_codes_localedir = _c_string(values["iso_codes_localedir"]),
        feature_defines = feature_defines,
    )
