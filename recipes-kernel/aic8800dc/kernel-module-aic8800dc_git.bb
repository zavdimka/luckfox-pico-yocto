SUMMARY = "AIC8800DC WiFi/BT kernel module driver"
DESCRIPTION = "AIC8800DC wireless LAN and Bluetooth driver module for RV1106"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

inherit module update-rc.d

PV = "1.0+git${SRCPV}"

SRC_URI = "git://github.com/LuckfoxTECH/luckfox-pico.git;protocol=https;branch=main;subpath=sysdrv/drv_ko/wifi/aic8800dc;destsuffix=git;name=aic8800dc \
           file://Makefile \
           file://aic8800dc-wifi.init \
"

SRCREV_aic8800dc = "${AUTOREV}"

S = "${WORKDIR}/git"

EXTRA_OEMAKE = ' \
    ARCH=${ARCH} \
    CROSS_COMPILE=${CROSS_COMPILE} \
    KDIR=${STAGING_KERNEL_BUILDDIR} \
'

# Copy our simplified Makefile to the source directory after unpacking
do_patch:append() {
    bb.plain("Installing custom Makefile for aic8800dc")
    import shutil
    makefile_src = os.path.join(d.getVar('WORKDIR'), 'sources-unpack', 'Makefile')
    makefile_dst = os.path.join(d.getVar('S'), 'Makefile')
    shutil.copy2(makefile_src, makefile_dst)
}

# Create a minimal Makefile wrapper in build artifacts if it doesn't exist
do_compile:prepend() {
    if [ ! -f "${STAGING_KERNEL_BUILDDIR}/Makefile" ]; then
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

# Install init script for automatic module loading
do_install:append() {
    install -d ${D}${sysconfdir}/init.d
    install -m 0755 ${WORKDIR}/sources-unpack/aic8800dc-wifi.init ${D}${sysconfdir}/init.d/aic8800dc-wifi
}

# Configure init script to run at boot
INITSCRIPT_NAME = "aic8800dc-wifi"
INITSCRIPT_PARAMS = "defaults 90"

# Package the init script
FILES:${PN} += "${sysconfdir}/init.d/aic8800dc-wifi"

# Kernel module class will handle installation
# Modules are installed to /lib/modules/<kernel-version>/extra/

RPROVIDES:${PN} += "kernel-module-aic8800dc"

COMPATIBLE_MACHINE = "luckfox-pico"
