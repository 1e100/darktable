/*
    This file is part of darktable,
    Copyright (C) 2026 darktable developers.

    darktable is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
*/

#include <stdint.h>
#include <string.h>

#include <gtest/gtest.h>
#include <glib.h>

extern "C" {
#include "ai/backend.h"
}

static char *g_model_root = nullptr;

static char *resolve_runfile(const char *path)
{
  if(!path || !path[0]) return nullptr;
  if(g_path_is_absolute(path) && g_file_test(path, G_FILE_TEST_EXISTS))
    return g_strdup(path);
  if(g_file_test(path, G_FILE_TEST_EXISTS))
    return g_strdup(path);

  const char *test_srcdir = g_getenv("TEST_SRCDIR");
  const char *test_workspace = g_getenv("TEST_WORKSPACE");
  if(test_srcdir && test_workspace)
  {
    char *candidate = g_build_filename(test_srcdir, test_workspace, path, NULL);
    if(g_file_test(candidate, G_FILE_TEST_EXISTS)) return candidate;
    g_free(candidate);
  }
  if(test_srcdir)
  {
    char *candidate = g_build_filename(test_srcdir, path, NULL);
    if(g_file_test(candidate, G_FILE_TEST_EXISTS)) return candidate;
    g_free(candidate);
  }
  return g_strdup(path);
}

class AIBackendTest : public ::testing::Test
{
protected:
  static void SetUpTestSuite()
  {
    env = dt_ai_env_init(g_model_root);
    ASSERT_NE(env, nullptr);
  }

  static void TearDownTestSuite()
  {
    dt_ai_env_destroy(env);
    env = nullptr;
  }

  static dt_ai_environment_t *env;
};

dt_ai_environment_t *AIBackendTest::env = nullptr;

TEST_F(AIBackendTest, DiscoversModel)
{
  ASSERT_EQ(dt_ai_get_model_count(env), 1);
  const dt_ai_model_info_t *info = dt_ai_get_model_info_by_index(env, 0);
  ASSERT_NE(info, nullptr);
  EXPECT_STREQ(info->id, "test-multiply");
  EXPECT_STREQ(info->name, "Test Multiply");
  EXPECT_STREQ(info->task_type, "test");
  EXPECT_STREQ(info->backend, "onnx");
  EXPECT_EQ(info->num_inputs, 1);

  EXPECT_EQ(dt_ai_get_model_info_by_id(env, "does-not-exist"), nullptr);
  ASSERT_NE(dt_ai_get_model_info_by_id(env, "test-multiply"), nullptr);
}

TEST_F(AIBackendTest, LoadsAndIntrospectsModel)
{
  dt_ai_context_t *ctx =
    dt_ai_load_model(env, "test-multiply", NULL, DT_AI_PROVIDER_CPU);
  ASSERT_NE(ctx, nullptr);

  EXPECT_EQ(dt_ai_get_input_count(ctx), 1);
  EXPECT_EQ(dt_ai_get_output_count(ctx), 1);
  EXPECT_STREQ(dt_ai_get_input_name(ctx, 0), "x");
  EXPECT_STREQ(dt_ai_get_output_name(ctx, 0), "y");
  EXPECT_EQ(dt_ai_get_input_type(ctx, 0), DT_AI_FLOAT);
  EXPECT_EQ(dt_ai_get_output_type(ctx, 0), DT_AI_FLOAT);

  int64_t shape[8] = {};
  const int ndim = dt_ai_get_output_shape(ctx, 0, shape, 8);
  ASSERT_EQ(ndim, 4);
  EXPECT_EQ(shape[0], 1);
  EXPECT_EQ(shape[1], 3);
  EXPECT_EQ(shape[2], 4);
  EXPECT_EQ(shape[3], 4);

  dt_ai_unload_model(ctx);
}

TEST_F(AIBackendTest, RunsInference)
{
  dt_ai_context_t *ctx =
    dt_ai_load_model(env, "test-multiply", NULL, DT_AI_PROVIDER_CPU);
  ASSERT_NE(ctx, nullptr);

  float input_data[48];
  float output_data[48];
  for(float &value : input_data) value = 1.0f;
  memset(output_data, 0, sizeof(output_data));

  int64_t shape[] = { 1, 3, 4, 4 };
  dt_ai_tensor_t input = {
    .data = input_data,
    .type = DT_AI_FLOAT,
    .shape = shape,
    .ndim = 4,
  };
  dt_ai_tensor_t output = {
    .data = output_data,
    .type = DT_AI_FLOAT,
    .shape = shape,
    .ndim = 4,
  };

  ASSERT_EQ(dt_ai_run(ctx, &input, 1, &output, 1), 0);
  for(float value : output_data) EXPECT_NEAR(value, 2.0f, 1e-6f);

  dt_ai_unload_model(ctx);
}

TEST_F(AIBackendTest, HandlesErrorPaths)
{
  EXPECT_EQ(dt_ai_load_model(NULL, "test-multiply", NULL, DT_AI_PROVIDER_CPU), nullptr);
  EXPECT_EQ(dt_ai_get_model_count(NULL), 0);
  EXPECT_EQ(dt_ai_get_model_info_by_index(NULL, 0), nullptr);
  EXPECT_EQ(dt_ai_get_model_info_by_id(NULL, "test-multiply"), nullptr);
  EXPECT_EQ(dt_ai_get_model_info_by_id(env, NULL), nullptr);
  EXPECT_EQ(dt_ai_load_model(env, "no-such-model", NULL, DT_AI_PROVIDER_CPU), nullptr);
  EXPECT_EQ(dt_ai_load_model(env, "test-multiply", "nonexistent.onnx",
                             DT_AI_PROVIDER_CPU), nullptr);

  float dummy[48];
  int64_t shape[] = { 1, 3, 4, 4 };
  dt_ai_tensor_t tensor = {
    .data = dummy,
    .type = DT_AI_FLOAT,
    .shape = shape,
    .ndim = 4,
  };
  EXPECT_NE(dt_ai_run(NULL, &tensor, 1, &tensor, 1), 0);
}

TEST_F(AIBackendTest, HandlesProviderAndRefresh)
{
  EXPECT_EQ(dt_ai_env_get_provider(env), DT_AI_PROVIDER_CPU);

  dt_ai_env_set_provider(env, DT_AI_PROVIDER_COREML);
  EXPECT_EQ(dt_ai_env_get_provider(env), DT_AI_PROVIDER_COREML);
  dt_ai_env_set_provider(env, DT_AI_PROVIDER_AUTO);
  EXPECT_EQ(dt_ai_env_get_provider(env), DT_AI_PROVIDER_AUTO);
  dt_ai_env_set_provider(env, DT_AI_PROVIDER_CPU);

  for(int i = 0; i < DT_AI_PROVIDER_COUNT; i++)
  {
    const char *str = dt_ai_providers[i].config_string;
    EXPECT_EQ(dt_ai_provider_from_string(str), dt_ai_providers[i].value);
  }
  EXPECT_STREQ(dt_ai_provider_to_string(DT_AI_PROVIDER_CPU), "CPU");
  EXPECT_EQ(dt_ai_provider_from_string("bogus"), DT_AI_PROVIDER_AUTO);
  EXPECT_EQ(dt_ai_provider_from_string(NULL), DT_AI_PROVIDER_AUTO);
  EXPECT_EQ(dt_ai_provider_from_string(""), DT_AI_PROVIDER_AUTO);

  const int before = dt_ai_get_model_count(env);
  dt_ai_env_refresh(env);
  EXPECT_EQ(dt_ai_get_model_count(env), before);
}

TEST_F(AIBackendTest, LoadsOptimizationLevels)
{
  dt_ai_context_t *ctx_basic =
    dt_ai_load_model_ext(env, "test-multiply", NULL, DT_AI_PROVIDER_CPU,
                         DT_AI_OPT_BASIC, NULL, 0, 0);
  ASSERT_NE(ctx_basic, nullptr);
  dt_ai_unload_model(ctx_basic);

  dt_ai_context_t *ctx_none =
    dt_ai_load_model_ext(env, "test-multiply", NULL, DT_AI_PROVIDER_CPU,
                         DT_AI_OPT_DISABLED, NULL, 0, 0);
  ASSERT_NE(ctx_none, nullptr);
  dt_ai_unload_model(ctx_none);
}

TEST(AIBackendStandaloneTest, EmptyEnvironment)
{
  dt_ai_environment_t *missing = dt_ai_env_init("/no/such/path/xyz");
  ASSERT_NE(missing, nullptr);
  EXPECT_EQ(dt_ai_get_model_count(missing), 0);
  dt_ai_env_destroy(missing);

  dt_ai_environment_t *defaults = dt_ai_env_init(NULL);
  ASSERT_NE(defaults, nullptr);
  dt_ai_env_destroy(defaults);
}

int main(int argc, char **argv)
{
  ::testing::InitGoogleTest(&argc, argv);
  if(argc < 3)
  {
    ADD_FAILURE() << "usage: backend_gtest <libonnxruntime> <model config>";
    return 1;
  }

  char *ort_library = resolve_runfile(argv[1]);
  g_setenv("DT_ORT_LIBRARY", ort_library, TRUE);
  g_free(ort_library);

  char *config_path = resolve_runfile(argv[2]);
  char *model_dir = g_path_get_dirname(config_path);
  g_model_root = g_path_get_dirname(model_dir);
  g_free(model_dir);
  g_free(config_path);

  const int rc = RUN_ALL_TESTS();
  g_free(g_model_root);
  return rc;
}
