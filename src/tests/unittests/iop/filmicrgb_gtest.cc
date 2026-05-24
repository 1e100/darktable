#include <gtest/gtest.h>

extern "C" {
void dt_test_filmicrgb_name(void);
void dt_test_filmicrgb_default_group(void);
void dt_test_filmicrgb_clamp_simd(void);
void dt_test_filmicrgb_pixel_rgb_norm_power(void);
void dt_test_filmicrgb_get_pixel_norm(void);
void dt_test_filmicrgb_log_tonemapping_v2(void);
void dt_test_filmicrgb_filmic_spline(void);
void dt_test_filmicrgb_filmic_desaturate_v1(void);
void dt_test_filmicrgb_linear_saturation(void);
}

TEST(FilmicRgbTest, Name)
{
  dt_test_filmicrgb_name();
}

TEST(FilmicRgbTest, DefaultGroup)
{
  dt_test_filmicrgb_default_group();
}

TEST(FilmicRgbTest, ClampSimd)
{
  dt_test_filmicrgb_clamp_simd();
}

TEST(FilmicRgbTest, PixelRgbNormPower)
{
  dt_test_filmicrgb_pixel_rgb_norm_power();
}

TEST(FilmicRgbTest, GetPixelNorm)
{
  dt_test_filmicrgb_get_pixel_norm();
}

TEST(FilmicRgbTest, LogTonemappingV2)
{
  dt_test_filmicrgb_log_tonemapping_v2();
}

TEST(FilmicRgbTest, FilmicSpline)
{
  dt_test_filmicrgb_filmic_spline();
}

TEST(FilmicRgbTest, FilmicDesaturateV1)
{
  dt_test_filmicrgb_filmic_desaturate_v1();
}

TEST(FilmicRgbTest, LinearSaturation)
{
  dt_test_filmicrgb_linear_saturation();
}
