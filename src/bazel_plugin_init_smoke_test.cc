#include <gtest/gtest.h>

extern "C" {
#include "common/darktable.h"
#include "develop/imageop.h"
#include "imageio/imageio_module.h"
}

#include <dirent.h>
#include <errno.h>
#include <glib.h>
#include <glib/gstdio.h>
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

std::string runtime_tree_arg;
std::atomic<unsigned> watchdog_generation{0};

bool is_directory(const std::string &path)
{
  struct stat st;
  return stat(path.c_str(), &st) == 0 && S_ISDIR(st.st_mode);
}

std::string join_path(const std::string &left, const std::string &right)
{
  return (std::filesystem::path(left) / right).string();
}

bool resolve_runtime_root(const std::string &arg, std::string *out)
{
  char resolved[PATH_MAX];
  if(realpath(arg.c_str(), resolved) && is_directory(resolved))
  {
    *out = resolved;
    return true;
  }

  const char *test_srcdir = getenv("TEST_SRCDIR");
  const char *test_workspace = getenv("TEST_WORKSPACE");
  if(test_srcdir && test_workspace)
  {
    const std::string candidate = join_path(join_path(test_srcdir, test_workspace), arg);
    if(realpath(candidate.c_str(), resolved) && is_directory(resolved))
    {
      *out = resolved;
      return true;
    }
  }

  if(test_srcdir)
  {
    const std::string candidate = join_path(test_srcdir, arg);
    if(realpath(candidate.c_str(), resolved) && is_directory(resolved))
    {
      *out = resolved;
      return true;
    }
  }

  return false;
}

bool is_plugin_filename(const char *name)
{
  const size_t len = strlen(name);
  return len > 6 && strncmp(name, "lib", 3) == 0 && strcmp(name + len - 3, ".so") == 0;
}

std::vector<std::string> read_plugin_names(const std::string &runtime_root, const std::string &subdir,
                                           std::string *error)
{
  std::vector<std::string> plugins;
  const std::string dir_path = join_path(runtime_root, subdir);
  DIR *dir = opendir(dir_path.c_str());
  if(!dir)
  {
    *error = "could not open plugin directory " + dir_path + ": " + g_strerror(errno);
    return plugins;
  }

  for(struct dirent *entry = readdir(dir); entry; entry = readdir(dir))
  {
    if(is_plugin_filename(entry->d_name))
    {
      const std::string filename(entry->d_name);
      plugins.push_back(filename.substr(3, filename.size() - 6));
    }
  }

  closedir(dir);
  std::sort(plugins.begin(), plugins.end());
  return plugins;
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

bool set_env_path(const char *name, const std::string &runtime_root, const std::string &suffix,
                  std::string *error)
{
  const std::string path = join_path(runtime_root, suffix);
  if(setenv(name, path.c_str(), 1) != 0)
  {
    *error = std::string("could not set ") + name + ": " + g_strerror(errno);
    return false;
  }
  return true;
}

dt_imageio_module_format_t *find_format(const std::string &name)
{
  for(GList *iter = darktable.imageio ? darktable.imageio->plugins_format : nullptr;
      iter;
      iter = g_list_next(iter))
  {
    auto *module = static_cast<dt_imageio_module_format_t *>(iter->data);
    if(name == module->plugin_name) return module;
  }
  return nullptr;
}

dt_imageio_module_storage_t *find_storage(const std::string &name)
{
  for(GList *iter = darktable.imageio ? darktable.imageio->plugins_storage : nullptr;
      iter;
      iter = g_list_next(iter))
  {
    auto *module = static_cast<dt_imageio_module_storage_t *>(iter->data);
    if(name == module->plugin_name) return module;
  }
  return nullptr;
}

dt_iop_module_so_t *find_iop(const std::string &name)
{
  for(GList *iter = darktable.iop; iter; iter = g_list_next(iter))
  {
    auto *module = static_cast<dt_iop_module_so_t *>(iter->data);
    if(name == module->op) return module;
  }
  return nullptr;
}

void start_watchdog(const char *phase)
{
  const unsigned generation = ++watchdog_generation;
  std::thread([generation, phase]() {
    std::this_thread::sleep_for(std::chrono::seconds(60));
    if(watchdog_generation.load() == generation)
    {
      const std::string message =
        std::string("bazel_plugin_init_smoke_test timed out in ") + phase + "\n";
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
  argv.reserve(storage->size());
  for(std::string &arg : *storage) argv.push_back(arg.data());
  return argv;
}

class PluginInitSmokeTest : public ::testing::Test
{
protected:
  static void SetUpTestSuite()
  {
    initialized_ = initialize();
  }

  static void TearDownTestSuite()
  {
    if(!initialized_) return;
    start_watchdog("dt_cleanup");
    dt_cleanup();
    stop_watchdog();
  }

  void SetUp() override
  {
    ASSERT_TRUE(initialized_) << init_error_;
  }

  static bool initialize()
  {
    if(!resolve_runtime_root(runtime_tree_arg, &runtime_root_))
    {
      init_error_ = "could not locate runtime tree: " + runtime_tree_arg;
      return false;
    }

    formats_ = read_plugin_names(runtime_root_, "lib/darktable/plugins/imageio/format", &init_error_);
    if(!init_error_.empty()) return false;
    storages_ = read_plugin_names(runtime_root_, "lib/darktable/plugins/imageio/storage", &init_error_);
    if(!init_error_.empty()) return false;
    iops_ = read_plugin_names(runtime_root_, "lib/darktable/plugins", &init_error_);
    if(!init_error_.empty()) return false;

    const char *tmp_env = getenv("TEST_TMPDIR");
    const std::string tmp_root = tmp_env && *tmp_env ? tmp_env : "/tmp";
    home_dir_ = join_path(tmp_root, "darktable-plugin-init-home");
    config_dir_ = join_path(tmp_root, "darktable-plugin-init-config");
    cache_dir_ = join_path(tmp_root, "darktable-plugin-init-cache");
    data_dir_ = join_path(tmp_root, "darktable-plugin-init-data");
    tmp_dir_ = join_path(tmp_root, "darktable-plugin-init-tmp");

    if(!prepare_dir(home_dir_, &init_error_)
       || !prepare_dir(config_dir_, &init_error_)
       || !prepare_dir(cache_dir_, &init_error_)
       || !prepare_dir(data_dir_, &init_error_)
       || !prepare_dir(tmp_dir_, &init_error_))
      return false;

    setenv("HOME", home_dir_.c_str(), 1);
    setenv("XDG_CONFIG_HOME", config_dir_.c_str(), 1);
    setenv("XDG_CACHE_HOME", cache_dir_.c_str(), 1);
    setenv("XDG_DATA_HOME", data_dir_.c_str(), 1);

    if(!set_env_path("ICU_DATA", runtime_root_, "share/darktable/icu", &init_error_)
       || !set_env_path("CAMLIBS", runtime_root_, "lib/darktable/libgphoto2/2.5.33", &init_error_)
       || !set_env_path("IOLIBS", runtime_root_, "lib/darktable/libgphoto2_port/0.12.2", &init_error_))
      return false;

    std::vector<std::string> args_storage = {
      "bazel_plugin_init_smoke_test",
      "--library",
      ":memory:",
      "--datadir",
      join_path(runtime_root_, "share/darktable"),
      "--moduledir",
      join_path(runtime_root_, "lib/darktable"),
      "--localedir",
      join_path(runtime_root_, "share/locale"),
      "--configdir",
      config_dir_,
      "--cachedir",
      cache_dir_,
      "--tmpdir",
      tmp_dir_,
      "--disable-opencl",
      "--conf",
      "write_sidecar_files=never",
    };
    std::vector<char *> args = mutable_argv(&args_storage);

    start_watchdog("dt_init");
    if(dt_init(static_cast<int>(args.size()), args.data(), FALSE, FALSE, nullptr))
    {
      stop_watchdog();
      init_error_ = "dt_init failed";
      return false;
    }
    stop_watchdog();
    return true;
  }

  static inline bool initialized_ = false;
  static inline std::string init_error_;
  static inline std::string runtime_root_;
  static inline std::string home_dir_;
  static inline std::string config_dir_;
  static inline std::string cache_dir_;
  static inline std::string data_dir_;
  static inline std::string tmp_dir_;
  static inline std::vector<std::string> formats_;
  static inline std::vector<std::string> storages_;
  static inline std::vector<std::string> iops_;
};

TEST_F(PluginInitSmokeTest, InitializesImageioFormats)
{
  ASSERT_NE(nullptr, darktable.imageio);
  for(const std::string &name : formats_)
  {
    SCOPED_TRACE(name);
    dt_imageio_module_format_t *module = find_format(name);
    ASSERT_NE(nullptr, module);
    EXPECT_NE(nullptr, module->module);
    EXPECT_NE(nullptr, module->name);
    EXPECT_NE(nullptr, module->init);
    EXPECT_NE(nullptr, module->cleanup);
    EXPECT_NE(nullptr, module->params_size);
    EXPECT_NE(nullptr, module->get_params);
    EXPECT_NE(nullptr, module->free_params);
    EXPECT_NE(nullptr, module->set_params);
    EXPECT_NE(nullptr, module->mime);
    EXPECT_NE(nullptr, module->extension);
    EXPECT_NE(nullptr, module->bpp);
    EXPECT_NE(nullptr, module->write_image);
    EXPECT_TRUE(module->ready);
  }
}

TEST_F(PluginInitSmokeTest, InitializesImageioStorage)
{
  ASSERT_NE(nullptr, darktable.imageio);
  for(const std::string &name : storages_)
  {
    SCOPED_TRACE(name);
    dt_imageio_module_storage_t *module = find_storage(name);
    ASSERT_NE(nullptr, module);
    EXPECT_NE(nullptr, module->module);
    EXPECT_NE(nullptr, module->name);
    EXPECT_NE(nullptr, module->gui_init);
    EXPECT_NE(nullptr, module->gui_cleanup);
    EXPECT_NE(nullptr, module->gui_reset);
    EXPECT_NE(nullptr, module->init);
    EXPECT_NE(nullptr, module->store);
    EXPECT_NE(nullptr, module->params_size);
    EXPECT_NE(nullptr, module->get_params);
    EXPECT_NE(nullptr, module->free_params);
    EXPECT_NE(nullptr, module->set_params);
  }
}

TEST_F(PluginInitSmokeTest, InitializesIops)
{
  for(const std::string &name : iops_)
  {
    SCOPED_TRACE(name);
    dt_iop_module_so_t *module = find_iop(name);
    ASSERT_NE(nullptr, module);
    EXPECT_NE(nullptr, module->module);
    EXPECT_NE(nullptr, module->name);
    EXPECT_NE(nullptr, module->default_colorspace);
    EXPECT_NE(nullptr, module->process);
    EXPECT_NE(nullptr, module->process_plain);
    if(module->introspection_init)
    {
      EXPECT_TRUE(module->have_introspection);
    }
  }
}

TEST_F(PluginInitSmokeTest, RepresentativePluginsPresent)
{
  EXPECT_NE(nullptr, find_format("jpeg"));
  EXPECT_NE(nullptr, find_storage("disk"));
  EXPECT_NE(nullptr, find_iop("exposure"));
  EXPECT_NE(nullptr, find_iop("filmicrgb"));
  EXPECT_NE(nullptr, find_iop("lens"));
}

} // namespace

int main(int argc, char **argv)
{
  ::testing::InitGoogleTest(&argc, argv);
  if(argc != 2)
  {
    fprintf(stderr, "usage: %s <runtime-tree>\n", argv[0]);
    return 2;
  }

  runtime_tree_arg = argv[1];
  return RUN_ALL_TESTS();
}
