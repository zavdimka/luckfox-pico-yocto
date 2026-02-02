SUMMARY = "AIC8800DC WiFi/BT kernel module driver"
DESCRIPTION = "AIC8800DC wireless LAN and Bluetooth driver module for RV1106"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

inherit module update-rc.d

PV = "1.0+git${SRCPV}"

SRC_URI = "git://github.com/LuckfoxTECH/luckfox-pico.git;protocol=https;branch=main;subpath=sysdrv/drv_ko/wifi/aic8800dc;destsuffix=git;name=aic8800dc \
           file://Makefile \
           file://aic8800_bsp-Kbuild \
           file://aic8800_fdrv-Kbuild \
           file://aic8800_btlpm-Kbuild \
           file://aic8800dc-wifi.init \
"

SRCREV_aic8800dc = "${AUTOREV}"

S = "${WORKDIR}/git"

# Disable buildpaths QA check for debug symbols
INSANE_SKIP:${PN}-dbg += "buildpaths"

EXTRA_OEMAKE = ' \
    ARCH=${ARCH} \
    CROSS_COMPILE=${CROSS_COMPILE} \
    KDIR=${STAGING_KERNEL_BUILDDIR} \
'

# Override do_configure to skip the clean step (building from git, always fresh)
do_configure() {
    :
}

# Replace SDK Makefile with our Yocto-compatible version
do_patch:append() {
    bb.plain("Installing Yocto-compatible Makefile and Kbuild files for aic8800dc")
    import shutil
    import os
    
    workdir = d.getVar('WORKDIR')
    srcdir = d.getVar('S')
    sources_unpack = os.path.join(workdir, 'sources-unpack')
    
    # Copy top-level Makefile
    shutil.copy2(os.path.join(sources_unpack, 'Makefile'), os.path.join(srcdir, 'Makefile'))
    
    # Copy Kbuild files to subdirectories and remove SDK Makefiles
    for module in ['aic8800_bsp', 'aic8800_fdrv', 'aic8800_btlpm']:
        module_dir = os.path.join(srcdir, module)
        # Remove SDK Makefile (it conflicts with our Kbuild)
        sdk_makefile = os.path.join(module_dir, 'Makefile')
        if os.path.exists(sdk_makefile):
            os.remove(sdk_makefile)
        # Copy our Kbuild file
        kbuild_src = os.path.join(sources_unpack, f'{module}-Kbuild')
        kbuild_dst = os.path.join(module_dir, 'Kbuild')
        shutil.copy2(kbuild_src, kbuild_dst)
}

# Copy Module.symvers from kernel build dir to module source for dependency tracking
do_compile:append() {
    if [ -f "${STAGING_KERNEL_BUILDDIR}/Module.symvers" ]; then
        cp ${STAGING_KERNEL_BUILDDIR}/Module.symvers ${B}/
    fi
}

# Install init script for automatic module loading
do_install:append() {
    install -d ${D}${sysconfdir}/init.d
    install -m 0755 ${WORKDIR}/sources-unpack/aic8800dc-wifi.init ${D}${sysconfdir}/init.d/aic8800dc-wifi
    
    # Install firmware files
    install -d ${D}${nonarch_base_libdir}/firmware/aic8800
    install -m 0644 ${S}/aic8800dc_fw/* ${D}${nonarch_base_libdir}/firmware/aic8800/
}

# Configure init script to run at boot
INITSCRIPT_NAME = "aic8800dc-wifi"
INITSCRIPT_PARAMS = "defaults 90"

# Package the init script and firmware
FILES:${PN} += "${sysconfdir}/init.d/aic8800dc-wifi"
FILES:${PN} += "${nonarch_base_libdir}/firmware/aic8800/*"

# Kernel module class will handle installation
# Modules are installed to /lib/modules/<kernel-version>/extra/
# Firmware is installed to /lib/firmware/aic8800/

RPROVIDES:${PN} += "kernel-module-aic8800dc"

COMPATIBLE_MACHINE = "luckfox-pico"
