#include <dirent.h>
#include <dlfcn.h>
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

typedef struct plugin_group_t
{
  const char *subdir;
  const char *const *required_symbols;
} plugin_group_t;

static const char *const common_symbols[] = {
  "dt_module_dt_version",
  "dt_module_mod_version",
  NULL,
};

static const char *const iop_symbols[] = {
  "dt_module_dt_version",
  "dt_module_mod_version",
  "name",
  "default_colorspace",
  "process",
  NULL,
};

static const char *const lighttable_symbols[] = {
  "dt_module_dt_version",
  "dt_module_mod_version",
  "name",
  "views",
  "container",
  "gui_init",
  "gui_cleanup",
  NULL,
};

static const char *const format_symbols[] = {
  "dt_module_dt_version",
  "dt_module_mod_version",
  "name",
  "gui_cleanup",
  "gui_reset",
  "init",
  "cleanup",
  "params_size",
  "get_params",
  "free_params",
  "set_params",
  "mime",
  "extension",
  "bpp",
  "write_image",
  NULL,
};

static const char *const storage_symbols[] = {
  "dt_module_dt_version",
  "dt_module_mod_version",
  "name",
  "gui_init",
  "gui_cleanup",
  "gui_reset",
  "init",
  "store",
  "params_size",
  "get_params",
  "free_params",
  "set_params",
  NULL,
};

static const plugin_group_t plugin_groups[] = {
  { "lib/darktable/views", common_symbols },
  { "lib/darktable/plugins", iop_symbols },
  { "lib/darktable/plugins/lighttable", lighttable_symbols },
  { "lib/darktable/plugins/imageio/format", format_symbols },
  { "lib/darktable/plugins/imageio/storage", storage_symbols },
};

static int is_directory(const char *path)
{
  struct stat st;
  return stat(path, &st) == 0 && S_ISDIR(st.st_mode);
}

static int is_plugin_name(const char *name)
{
  const size_t len = strlen(name);
  return len > 6 && strncmp(name, "lib", 3) == 0 && strcmp(name + len - 3, ".so") == 0;
}

static int path_join(char *out, size_t out_size, const char *left, const char *right)
{
  const int written = snprintf(out, out_size, "%s/%s", left, right);
  return written > 0 && (size_t)written < out_size;
}

static int resolve_runtime_root(char *out, size_t out_size, const char *arg)
{
  const char *test_srcdir = getenv("TEST_SRCDIR");
  const char *test_workspace = getenv("TEST_WORKSPACE");
  char workspace_root[PATH_MAX];
  char candidate[PATH_MAX];

  const char *candidates[2] = { arg, NULL };
  for(size_t i = 0; i < 2; i++)
  {
    if(!candidates[i]) continue;
    if(realpath(candidates[i], out) && is_directory(out)) return 1;
  }

  if(test_srcdir && test_workspace)
  {
    if(!path_join(workspace_root, sizeof(workspace_root), test_srcdir, test_workspace)) return 0;
    if(!path_join(candidate, sizeof(candidate), workspace_root, arg)) return 0;
    if(realpath(candidate, out) && is_directory(out)) return 1;
  }

  if(test_srcdir)
  {
    if(!path_join(candidate, sizeof(candidate), test_srcdir, arg)) return 0;
    if(realpath(candidate, out) && is_directory(out)) return 1;
  }

  return 0;
}

static int check_symbols(void *handle, const char *path, const char *const *symbols)
{
  int failures = 0;

  for(const char *const *symbol = symbols; *symbol; symbol++)
  {
    dlerror();
    void *value = dlsym(handle, *symbol);
    const char *error = dlerror();
    if(error || !value)
    {
      fprintf(stderr, "missing symbol %s in %s: %s\n",
              *symbol, path, error ? error : "null symbol");
      failures++;
    }
  }

  return failures;
}

static int check_plugin_group(const char *runtime_root, const plugin_group_t *group, int *loaded)
{
  char dir_path[PATH_MAX];
  if(!path_join(dir_path, sizeof(dir_path), runtime_root, group->subdir))
  {
    fprintf(stderr, "path too long: %s/%s\n", runtime_root, group->subdir);
    return 1;
  }

  DIR *dir = opendir(dir_path);
  if(!dir)
  {
    fprintf(stderr, "could not open plugin directory %s: %s\n", dir_path, strerror(errno));
    return 1;
  }

  int failures = 0;
  int group_loaded = 0;

  for(struct dirent *entry = readdir(dir); entry; entry = readdir(dir))
  {
    if(!is_plugin_name(entry->d_name)) continue;

    char plugin_path[PATH_MAX];
    if(!path_join(plugin_path, sizeof(plugin_path), dir_path, entry->d_name))
    {
      fprintf(stderr, "path too long: %s/%s\n", dir_path, entry->d_name);
      failures++;
      continue;
    }

    void *handle = dlopen(plugin_path, RTLD_LAZY | RTLD_LOCAL);
    if(!handle)
    {
      fprintf(stderr, "could not dlopen %s: %s\n", plugin_path, dlerror());
      failures++;
      continue;
    }

    failures += check_symbols(handle, plugin_path, group->required_symbols);
    dlclose(handle);
    group_loaded++;
  }

  closedir(dir);

  if(group_loaded == 0)
  {
    fprintf(stderr, "no plugins found in %s\n", dir_path);
    failures++;
  }

  *loaded += group_loaded;
  return failures;
}

int main(int argc, char **argv)
{
  if(argc != 2)
  {
    fprintf(stderr, "usage: %s <runtime-tree>\n", argv[0]);
    return 2;
  }

  char runtime_root[PATH_MAX];
  if(!resolve_runtime_root(runtime_root, sizeof(runtime_root), argv[1]))
  {
    fprintf(stderr, "could not locate runtime tree: %s\n", argv[1]);
    return 1;
  }

  int failures = 0;
  int loaded = 0;
  for(size_t i = 0; i < sizeof(plugin_groups) / sizeof(plugin_groups[0]); i++)
    failures += check_plugin_group(runtime_root, &plugin_groups[i], &loaded);

  if(failures)
  {
    fprintf(stderr, "plugin load smoke failed: %d failures across %d loaded plugins\n", failures, loaded);
    return 1;
  }

  printf("plugin load smoke passed: loaded %d plugins from %s\n", loaded, runtime_root);
  return 0;
}
