APP_ABI := armeabi-v7a
APP_CFLAGS := -ffast-math -fno-strict-aliasing -funroll-loops -Werror=return-type
APP_CPPFLAGS := -fexceptions -frtti
APP_OPTIM := release
APP_PLATFORM := android-16
APP_STL := gnustl_shared
NDK_APP_SHORT_COMMANDS := true
NDK_TOOLCHAIN_VERSION := 4.9

APP_MODULES := \
  angelscript \
  freetype \
  jpeg \
  ogg \
  png \
  vorbis \
  \
  angelwrap \
  ftlib \
  irc \
  ref_gl
