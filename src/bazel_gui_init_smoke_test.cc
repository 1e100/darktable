#include <glib.h>

extern "C" {
#include "common/darktable.h"
}

#include "views/view.h"

#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include <algorithm>
#include <atomic>
#include <chrono>
#include <filesystem>
#include <string>
#include <thread>
#include <vector>

namespace
{

std::atomic<unsigned> watchdog_generation{0};

bool is_directory(const std::string &path)
{
  struct stat st;
  return stat(path.c_str(), &st) == 0 && S_ISDIR(st.st_mode);
}

bool is_file(const std::string &path)
{
  struct stat st;
  return stat(path.c_str(), &st) == 0 && S_ISREG(st.st_mode);
}

std::string join_path(const std::string &left, const std::string &right)
{
  return (std::filesystem::path(left) / right).string();
}

bool resolve_path(const std::string &arg, bool (*predicate)(const std::string &), std::string *out)
{
  char resolved[PATH_MAX];
  if(realpath(arg.c_str(), resolved) && predicate(resolved))
  {
    *out = resolved;
    return true;
  }

  const char *test_srcdir = getenv("TEST_SRCDIR");
  const char *test_workspace = getenv("TEST_WORKSPACE");
  if(test_srcdir && test_workspace)
  {
    const std::string candidate = join_path(join_path(test_srcdir, test_workspace), arg);
    if(realpath(candidate.c_str(), resolved) && predicate(resolved))
    {
      *out = resolved;
      return true;
    }
  }

  if(test_srcdir)
  {
    const std::string candidate = join_path(test_srcdir, arg);
    if(realpath(candidate.c_str(), resolved) && predicate(resolved))
    {
      *out = resolved;
      return true;
    }
  }

  return false;
}

bool prepare_dir(const std::string &path, std::string *error)
{
  if(g_mkdir_with_parents(path.c_str(), 0700) != 0)
  {
    *error = "could not create " + path + ": " + g_strerror(errno);
    return false;
  }
  return true;
}

bool set_env(const char *name, const std::string &value, std::string *error)
{
  if(setenv(name, value.c_str(), 1) != 0)
  {
    *error = std::string("could not set ") + name + ": " + g_strerror(errno);
    return false;
  }
  return true;
}

bool prepare_environment(const std::string &runtime_root, const std::string &tmp_root,
                         std::string *error)
{
  const std::string home_dir = join_path(tmp_root, "darktable-gui-init-home");
  const std::string config_dir = join_path(tmp_root, "darktable-gui-init-config");
  const std::string cache_dir = join_path(tmp_root, "darktable-gui-init-cache");
  const std::string data_dir = join_path(tmp_root, "darktable-gui-init-data");
  const std::string tmp_dir = join_path(tmp_root, "darktable-gui-init-tmp");

  if(!prepare_dir(home_dir, error)
     || !prepare_dir(config_dir, error)
     || !prepare_dir(cache_dir, error)
     || !prepare_dir(data_dir, error)
     || !prepare_dir(tmp_dir, error))
    return false;

  return set_env("HOME", home_dir, error)
         && set_env("XDG_CONFIG_HOME", config_dir, error)
         && set_env("XDG_CACHE_HOME", cache_dir, error)
         && set_env("XDG_DATA_HOME", data_dir, error)
         && set_env("ICU_DATA", join_path(runtime_root, "share/darktable/icu"), error)
         && set_env("CAMLIBS", join_path(runtime_root, "lib/darktable/libgphoto2/2.5.33"), error)
         && set_env("IOLIBS", join_path(runtime_root, "lib/darktable/libgphoto2_port/0.12.2"), error)
         && set_env("NO_AT_BRIDGE", "1", error)
         && set_env("GDK_BACKEND", "x11", error);
}

void start_watchdog(const char *phase)
{
  const unsigned generation = ++watchdog_generation;
  std::thread([generation, phase]() {
    std::this_thread::sleep_for(std::chrono::seconds(60));
    if(watchdog_generation.load() == generation)
    {
      const std::string message = std::string("bazel_gui_init_smoke_test timed out in ") + phase + "\n";
      write(STDERR_FILENO, message.c_str(), message.size());
      _exit(124);
    }
  }).detach();
}

void stop_watchdog()
{
  ++watchdog_generation;
}

std::vector<char *> mutable_argv(std::vector<std::string> *storage)
{
  std::vector<char *> argv;
  argv.reserve(storage->size() + 1);
  for(std::string &arg : *storage) argv.push_back(arg.data());
  argv.push_back(nullptr);
  return argv;
}

dt_view_t *find_view(const char *name)
{
  for(GList *iter = darktable.view_manager ? darktable.view_manager->views : nullptr;
      iter;
      iter = g_list_next(iter))
  {
    auto *view = static_cast<dt_view_t *>(iter->data);
    if(view && strcmp(view->module_name, name) == 0) return view;
  }
  return nullptr;
}

bool require_view(const char *name)
{
  dt_view_t *view = find_view(name);
  if(!view)
  {
    fprintf(stderr, "missing initialized view: %s\n", name);
    return false;
  }
  if(!view->module || !view->name || !view->view)
  {
    fprintf(stderr, "view %s is missing required callbacks\n", name);
    return false;
  }
  return true;
}

void drain_main_context()
{
  for(int i = 0; i < 20 && g_main_context_pending(nullptr); i++)
    g_main_context_iteration(nullptr, FALSE);
}

} // namespace

int main(int argc, char **argv)
{
  if(argc != 2)
  {
    fprintf(stderr, "usage: %s <runtime-tree>\n", argv[0]);
    return 2;
  }

  std::string runtime_root;
  if(!resolve_path(argv[1], is_directory, &runtime_root))
  {
    fprintf(stderr, "could not locate runtime tree: %s\n", argv[1]);
    return 1;
  }

  std::string error;
  const char *tmp_env = getenv("TEST_TMPDIR");
  const std::string tmp_root = tmp_env && *tmp_env ? tmp_env : "/tmp";
  if(!prepare_environment(runtime_root, tmp_root, &error))
  {
    fprintf(stderr, "%s\n", error.c_str());
    return 1;
  }

  std::vector<std::string> args_storage = {
    "bazel_gui_init_smoke_test",
    "--library",
    ":memory:",
    "--datadir",
    join_path(runtime_root, "share/darktable"),
    "--moduledir",
    join_path(runtime_root, "lib/darktable"),
    "--localedir",
    join_path(runtime_root, "share/locale"),
    "--configdir",
    join_path(tmp_root, "darktable-gui-init-config/darktable"),
    "--cachedir",
    join_path(tmp_root, "darktable-gui-init-cache/darktable"),
    "--tmpdir",
    join_path(tmp_root, "darktable-gui-init-tmp"),
    "--disable-opencl",
    "--conf",
    "write_sidecar_files=never",
    "--conf",
    "plugins/lighttable/collect/ask_before_delete=false",
    "--conf",
    "performance_configuration_version_completed=19",
    "--conf",
    "ui/show_welcome_screen=false",
  };
  std::vector<char *> args = mutable_argv(&args_storage);

  start_watchdog("dt_init");
  const int init_status = dt_init(static_cast<int>(args_storage.size()), args.data(), TRUE, TRUE, nullptr);
  stop_watchdog();
  if(init_status)
  {
    fprintf(stderr, "dt_init failed with status %d\n", init_status);
    return 1;
  }

  drain_main_context();

  bool ok = true;
  if(!darktable.gui)
  {
    fprintf(stderr, "darktable.gui was not initialized\n");
    ok = false;
  }
  if(!darktable.view_manager)
  {
    fprintf(stderr, "darktable.view_manager was not initialized\n");
    ok = false;
  }
  else
  {
    ok = require_view("lighttable") && ok;
    ok = require_view("darkroom") && ok;
    ok = require_view("slideshow") && ok;
    ok = require_view("tethering") && ok;
    if(is_file(join_path(runtime_root, "lib/darktable/views/libmap.so")))
      ok = require_view("map") && ok;
    if(is_file(join_path(runtime_root, "lib/darktable/views/libprint.so")))
      ok = require_view("print") && ok;

    if(!darktable.view_manager->current_view)
      fprintf(stderr, "no current view selected after GUI init\n");
  }

  start_watchdog("dt_cleanup");
  dt_cleanup();
  stop_watchdog();

  return ok ? 0 : 1;
}
