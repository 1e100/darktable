#include "common/darktable.h"
#include "common/variables.h"

#include <errno.h>
#include <glib/gstdio.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#ifdef _WIN32
#include "win/main_wrapper.h"
#endif

typedef struct test_case_t
{
  char *input, *expected_result;
} test_case_t;

typedef struct test_t
{
  char *filename, *jobcode, sequence;
  test_case_t test_cases[];
} test_t;

int run_test(const test_t *test, int *n_tests, int *n_failed)
{
  dt_variables_params_t *params;
  dt_variables_params_init(&params);
  params->filename = test->filename;//"abcdef12345abcdef";
  params->jobcode = test->jobcode;//"ABCDEF12345ABCDEF";
  params->sequence = test->sequence;

  *n_failed = 0;
  *n_tests = 0;
  for(const test_case_t *test_case = test->test_cases; test_case->input; test_case++)
  {
    (*n_tests)++;
    char *result = dt_variables_expand(params, test_case->input, FALSE);
    if(g_strcmp0(result, test_case->expected_result))
    {
      (*n_failed)++;
      printf("  [FAIL] input: '%s', result: '%s', expected: '%s'\n", test_case->input, result, test_case->expected_result);
    }
    else
      printf("  [OK] input: '%s', result: '%s'\n", test_case->input, result);
  }

  dt_variables_params_destroy(params);

  return *n_failed > 0 ? 1 : 0;
}

static const test_t test_variables = {
  "abcdef12345abcdef", "ABCDEF12345ABCDEF", 23,
  {
    {"$(FILE_NAME)", "abcdef12345abcdef"},
    {"foo-$(FILE_NAME)-bar", "foo-abcdef12345abcdef-bar"},
    {"äöü-$(FILE_NAME)-äöü", "äöü-abcdef12345abcdef-äöü"},
    {"$(FILE_NAME).$(SEQUENCE)", "abcdef12345abcdef.0023"},
    {"$(NONEXISTANT)", ""},
    {"foo-$(NONEXISTANT)-bar", "foo--bar"},

    {NULL, NULL}
  }
};

static const test_t test_simple_substitutions = {
  "abcdef12345abcdef", "ABCDEF12345ABCDEF", 23,
  {
    {"$(NONEXISTANT-invälid)", "invälid"},
    {"$(FILE_NAME-invälid)", "abcdef12345abcdef"},

    {"$(NONEXISTANT+exißts)", ""},
    {"$(FILE_NAME+exißts)", "exißts"},

    {"$(NONEXISTANT:0)", ""},
    {"$(FILE_NAME:0)", "abcdef12345abcdef"},
    {"$(FILE_NAME:5)", "f12345abcdef"},
    {"$(FILE_NAME:42)", ""},
    {"$(FILE_NAME:-5)", "bcdef"},
    {"$(FILE_NAME:-42)", "abcdef12345abcdef"},
    {"$(FILE_NAME:0:5)", "abcde"},
    {"$(FILE_NAME:5:3)", "f12"},
    {"$(FILE_NAME:5:42)", "f12345abcdef"},
    {"$(FILE_NAME:-5:3)", "bcd"},
    {"$(FILE_NAME:-7:-2)", "5abcd"},
    {"$(FILE_NAME:)", "abcdef12345abcdef"},
    {"$(FILE_NAME:5:)", ""},

    {"$(NONEXISTANT#abc)", ""},
    {"$(FILE_NAME#abc)", "def12345abcdef"},
    {"$(FILE_NAME#def)", "abcdef12345abcdef"},

    {"$(NONEXISTANT%abc)", ""},
    {"$(FILE_NAME%abc)", "abcdef12345abcdef"},
    {"$(FILE_NAME%def)", "abcdef12345abc"},

    {"$(NONEXISTANT/abc/def)", ""},
    {"$(FILE_NAME/abc/foobar)", "foobardef12345abcdef"},
    {"$(FILE_NAME/def/foobar)", "abcfoobar12345abcdef"},
    {"$(FILE_NAME//abc/foobar)", "foobardef12345foobardef"},
    {"$(FILE_NAME//def/foobar)", "abcfoobar12345abcfoobar"},
    {"$(FILE_NAME/#abc/foobar)", "foobardef12345abcdef"},
    {"$(FILE_NAME/#def/foobar)", "abcdef12345abcdef"},
    {"$(FILE_NAME/%abc/foobar)", "abcdef12345abcdef"},
    {"$(FILE_NAME/%def/foobar)", "abcdef12345abcfoobar"},

    {"$(NONEXISTANT^)", ""},
    {"$(NONEXISTANT^^)", ""},
    {"$(FILE_NAME^)", "Abcdef12345abcdef"},
    {"$(FILE_NAME^^)", "ABCDEF12345ABCDEF"},

    {"$(NONEXISTANT,)", ""},
    {"$(NONEXISTANT,,)", ""},
    {"$(JOBCODE,)", "aBCDEF12345ABCDEF"},
    {"$(JOBCODE,,)", "abcdef12345abcdef"},

    {NULL, NULL}
  }
};

static const test_t test_recursive_substitutions = {
  "abcdef12345abcdef", "ABCDEF12345ABCDEF", 23,
  {
    {"x$(TITLE-$(FILE_NAME))y", "xabcdef12345abcdefy"},
    {"x$(TITLE-a-$(FILE_NAME)-b)y", "xa-abcdef12345abcdef-by"},
    {"x$(SEQUENCE-$(FILE_NAME))y", "x0023y"},
    {"x$(FILE_NAME/12345/$(SEQUENCE))y", "xabcdef0023abcdefy"},
    {"x$(FILE_NAME/12345/.$(SEQUENCE).)y", "xabcdef.0023.abcdefy"},

    {NULL, NULL}
  }
};

static const test_t test_broken_variables = {
  "abcdef12345abcdef", "ABCDEF12345ABCDEF", 23,
  {
    {"$(NONEXISTANT", "$(NONEXISTANT"},
    {"x(NONEXISTANT23", "x(NONEXISTANT23"},
    {"$(FILE_NAME", "$(FILE_NAME"},
    {"x$(FILE_NAME", "x$(FILE_NAME"},
    {"x$(TITLE-$(FILE_NAME)", "x$(TITLE-abcdef12345abcdef"},

    {NULL, NULL}
  }
};

static const test_t test_escapes = {
  "/home/test/Images/IMG_0123.CR2", "/home/test/", 23,
  {
    {"foobarbaz", "foobarbaz"},
    {"foo/bar/baz", "foo/bar/baz"},
    {"foo\\bar\\baz", "foobarbaz"},
    {"foo\\\\bar\\\\baz", "foo\\bar\\baz"},
    {"foo\\$(bar", "foo$(bar"},
    {"foo$\\(bar", "foo$(bar"},
    {"foo\\$\\(bar", "foo$(bar"},
    {"foo\\$(bar$(SEQUENCE)baz", "foo$(bar0023baz"},
    {"foo$(bar$(SEQUENCE)baz", "foo$(bar0023baz"},
    {"$(FILE_FOLDER)/darktable_exported/img_$(SEQUENCE)", "/home/test/Images/darktable_exported/img_0023"},
    {"$(FILE_FOLDER)/darktable_exported/$(FILE_NAME)", "/home/test/Images/darktable_exported/IMG_0123"},

    {NULL, NULL}
  }
};

static const test_t test_real_paths = {
  "/home/test/Images/0023/IMG_0123.CR2", "/home/test", 23,
  {
    {"$(FILE_FOLDER#$(JOBCODE))", "/Images/0023"},
    {"$(FILE_FOLDER#$(JOBCODE)/Images)", "/0023"},

    {"$(FILE_FOLDER%$(SEQUENCE))", "/home/test/Images/"},
    {"$(FILE_FOLDER%/$(SEQUENCE))", "/home/test/Images"},

    {"$(FILE_FOLDER/test/$(SEQUENCE))", "/home/0023/Images/0023"},
    {"$(FILE_FOLDER/test/$(SEQUENCE)-$(SEQUENCE))", "/home/0023-0023/Images/0023"},
    {"$(FILE_FOLDER/test/$(SEQUENCE//0/o))", "/home/oo23/Images/0023"},
    {"$(FILE_FOLDER/$(SEQUENCE)/XXX)", "/home/test/Images/XXX"},
    {"$(FILE_FOLDER/$(JOBCODE)\\///media/)", "/media/Images/0023"},
    {"$(FILE_FOLDER/\\/home\\/test\\///media/exports/)/darktable_exported/img_$(SEQUENCE)", "/media/exports/Images/0023/darktable_exported/img_0023"},

    {"$(FILE_FOLDER/", "$(FILE_FOLDER/"},
    {"$(FILE_FOLDER/home", "$(FILE_FOLDER/home"},
    {"$(FILE_FOLDER/home/media", "$(FILE_FOLDER/home/media"},
    {"$(FILE_FOLDER/home/media)", "/media/test/Images/0023"},

    {NULL, NULL}
  }
};


#define TEST(t) \
{\
    int n_failed = 0, n_tests = 0;\
    n_test_functions++;\
    printf("running test '" #t "'\n");\
    n_test_functions_failed += run_test(&t, &n_tests, &n_failed);\
    n_tests_overall += n_tests;\
    n_failed_overall += n_failed;\
    printf("%d / %d tests failed\n\n", n_failed, n_tests);\
}

static gboolean is_directory(const char *path)
{
  struct stat st;
  return path && stat(path, &st) == 0 && S_ISDIR(st.st_mode);
}

static char *join_path(const char *left, const char *right)
{
  return g_build_filename(left, right, NULL);
}

static char *resolve_runtime_root(const char *arg)
{
  if(!arg || !*arg) return NULL;

  char resolved[PATH_MAX];
  if(realpath(arg, resolved) && is_directory(resolved)) return g_strdup(resolved);

  const char *test_srcdir = getenv("TEST_SRCDIR");
  const char *test_workspace = getenv("TEST_WORKSPACE");
  if(test_srcdir && test_workspace)
  {
    char *candidate = g_build_filename(test_srcdir, test_workspace, arg, NULL);
    char *result = realpath(candidate, resolved) && is_directory(resolved) ? g_strdup(resolved) : NULL;
    g_free(candidate);
    if(result) return result;
  }

  if(test_srcdir)
  {
    char *candidate = g_build_filename(test_srcdir, arg, NULL);
    char *result = realpath(candidate, resolved) && is_directory(resolved) ? g_strdup(resolved) : NULL;
    g_free(candidate);
    if(result) return result;
  }

  return NULL;
}

static gboolean prepare_dir(const char *path)
{
  if(g_mkdir_with_parents(path, 0700) == 0) return TRUE;
  fprintf(stderr, "could not create %s: %s\n", path, g_strerror(errno));
  return FALSE;
}

static gboolean set_env_path(const char *name, const char *runtime_root, const char *suffix)
{
  char *path = join_path(runtime_root, suffix);
  const int result = setenv(name, path, 1);
  if(result != 0) fprintf(stderr, "could not set %s: %s\n", name, g_strerror(errno));
  g_free(path);
  return result == 0;
}

int main(int argc, char* argv[])
{
  char *runtime_root = resolve_runtime_root(argc > 1 ? argv[1] : NULL);
  const char *tmp_env = getenv("TEST_TMPDIR");
  const char *tmp_root = tmp_env && *tmp_env ? tmp_env : "/tmp";
  char *home_dir = join_path(tmp_root, "darktable-variables-home");
  char *config_dir = join_path(tmp_root, "darktable-variables-config");
  char *cache_dir = join_path(tmp_root, "darktable-variables-cache");
  char *data_dir = join_path(tmp_root, "darktable-variables-data");
  char *tmp_dir = join_path(tmp_root, "darktable-variables-tmp");

  if(!runtime_root)
  {
    fprintf(stderr, "usage: %s <bazel-runtime-tree>\n", argv[0]);
    exit(2);
  }

  if(!prepare_dir(home_dir)
     || !prepare_dir(config_dir)
     || !prepare_dir(cache_dir)
     || !prepare_dir(data_dir)
     || !prepare_dir(tmp_dir))
    exit(2);

  setenv("HOME", home_dir, 1);
  setenv("XDG_CONFIG_HOME", config_dir, 1);
  setenv("XDG_CACHE_HOME", cache_dir, 1);
  setenv("XDG_DATA_HOME", data_dir, 1);

  if(!set_env_path("ICU_DATA", runtime_root, "share/darktable/icu")
     || !set_env_path("CAMLIBS", runtime_root, "lib/darktable/libgphoto2/2.5.33")
     || !set_env_path("IOLIBS", runtime_root, "lib/darktable/libgphoto2_port/0.12.2"))
    exit(2);

  char *dt_datadir = join_path(runtime_root, "share/darktable");
  char *dt_moduledir = join_path(runtime_root, "lib/darktable");
  char *dt_localedir = join_path(runtime_root, "share/locale");
  char *argv_override[] = {
    "darktable-test-variables",
    "--library", ":memory:",
    "--datadir", dt_datadir,
    "--moduledir", dt_moduledir,
    "--localedir", dt_localedir,
    "--configdir", config_dir,
    "--cachedir", cache_dir,
    "--tmpdir", tmp_dir,
    "--disable-opencl",
    "--conf", "write_sidecar_files=never",
    NULL
  };
  int argc_override = sizeof(argv_override) / sizeof(*argv_override) - 1;

  // init dt without gui and without data.db:
  if(dt_init(argc_override, argv_override, FALSE, FALSE, NULL)) exit(1);

  int n_tests_overall = 0, n_failed_overall = 0, n_test_functions = 0, n_test_functions_failed = 0;

  TEST(test_variables)

  TEST(test_simple_substitutions)

  TEST(test_recursive_substitutions)

  TEST(test_broken_variables)

  TEST(test_escapes)

  TEST(test_real_paths)

  printf("%d / %d tests failed (%d / %d)\n",
         n_failed_overall,
         n_tests_overall,
         n_test_functions_failed,
         n_test_functions);

  dt_cleanup();

  g_free(dt_localedir);
  g_free(dt_moduledir);
  g_free(dt_datadir);
  g_free(tmp_dir);
  g_free(data_dir);
  g_free(cache_dir);
  g_free(config_dir);
  g_free(home_dir);
  g_free(runtime_root);

  return n_failed_overall ? 1 : 0;
}
// clang-format off
// modelines: These editor modelines have been set for all relevant files by tools/update_modelines.py
// vim: shiftwidth=2 expandtab tabstop=2 cindent
// kate: tab-indents: off; indent-width 2; replace-tabs on; indent-mode cstyle; remove-trailing-spaces modified;
// clang-format on
