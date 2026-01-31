# External Rockchip ARM toolchain configuration for Luckfox
#
# This class configures recipes to use the arm-rockchip830-linux-uclibcgnueabihf
# toolchain from the Luckfox SDK for kernel and U-Boot builds.

# Toolchain configuration
EXTERNAL_TOOLCHAIN_PREFIX = "arm-rockchip830-linux-uclibcgnueabihf-"

# Point directly to the toolchain in the SDK (no packaging needed)
# TOPDIR is build-luckfox, go up 3 levels to luckfox-pico root
EXTERNAL_TOOLCHAIN_PATH = "${TOPDIR}/../../tools/linux/toolchain/arm-rockchip830-linux-uclibcgnueabihf"
EXTERNAL_TOOLCHAIN_BIN = "${EXTERNAL_TOOLCHAIN_PATH}/bin"

# Export toolchain environment
export CROSS_COMPILE = "${EXTERNAL_TOOLCHAIN_PREFIX}"
export PATH:prepend = "${EXTERNAL_TOOLCHAIN_BIN}:"
export ARCH = "arm"
