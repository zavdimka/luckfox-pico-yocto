SUMMARY = "AIC8800DC WiFi/BT kernel module driver"
DESCRIPTION = "AIC8800DC wireless LAN and Bluetooth driver module for RV1106"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

inherit module

PV = "1.0+git${SRCPV}"

SRC_URI = "git://github.com/LuckfoxTECH/luckfox-pico.git;protocol=https;branch=main;subpath=sysdrv/drv_ko/wifi/aic8800dc;destsuffix=git \
           file://0001-support-out-of-tree-kernel-build.patch \
"

SRCREV = "${AUTOREV}"

S = "${WORKDIR}/git"

MAKE_TARGETS = "modules"

# Use build artifacts directory as KDIR since it has all kernel headers and Module.symvers
EXTRA_OEMAKE = ' \
    ARCH=${ARCH} \
    CROSS_COMPILE=${CROSS_COMPILE} \
    KDIR=${STAGING_KERNEL_BUILDDIR} \
    CONFIG_PLATFORM_ROCKCHIP=y \
    CONFIG_PLATFORM_ROCKCHIP2=n \
    CONFIG_PLATFORM_ALLWINNER=n \
    CONFIG_PLATFORM_AMLOGIC=n \
    CONFIG_PLATFORM_UBUNTU=n \
    CONFIG_AIC8800_BTLPM_SUPPORT=m \
    CONFIG_AIC8800_WLAN_SUPPORT=m \
    CONFIG_AIC_WLAN_SUPPORT=m \
'

# Create a minimal Makefile wrapper in build artifacts if it doesn't exist
do_compile:prepend() {
    if [ ! -f "${STAGING_KERNEL_BUILDDIR}/Makefile" ]; then
        # Create a minimal Makefile that includes the kernel source Makefile
        cat > ${STAGING_KERNEL_BUILDDIR}/Makefile << 'EOFMK'
# Wrapper Makefile for out-of-tree module builds
# Forward all targets to the kernel source tree
MAKEFLAGS += --no-print-directory
.PHONY: all modules modules_install clean

%:
	@$(MAKE) -C ${STAGING_KERNEL_DIR} O=${STAGING_KERNEL_BUILDDIR} $@
EOFMK
    fi
}

# Kernel module class will handle installation
# Modules are installed to /lib/modules/<kernel-version>/extra/

RPROVIDES:${PN} += "kernel-module-aic8800dc"

COMPATIBLE_MACHINE = "luckfox-pico"
