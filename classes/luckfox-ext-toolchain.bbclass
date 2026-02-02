# External Rockchip ARM toolchain configuration for Luckfox
#
# This class configures recipes to use the arm-rockchip830-linux-uclibcgnueabihf
# toolchain from the Luckfox SDK for kernel and U-Boot builds.
# The toolchain is fetched from GitHub via arm-rockchip830-toolchain-native recipe.

# Add dependency on the native toolchain recipe
DEPENDS += "arm-rockchip830-toolchain-native"

# Toolchain configuration - tools are in standard STAGING_BINDIR_NATIVE via symlinks
EXTERNAL_TOOLCHAIN_PREFIX = "arm-rockchip830-linux-uclibcgnueabihf-"

# Export toolchain environment
export CROSS_COMPILE = "${EXTERNAL_TOOLCHAIN_PREFIX}"
export ARCH = "arm"
