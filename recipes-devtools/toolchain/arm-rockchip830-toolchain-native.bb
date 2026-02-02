SUMMARY = "Rockchip ARM toolchain (GCC 8.3.0 + uclibc)"
DESCRIPTION = "External ARM toolchain from Luckfox SDK for RV1106"
LICENSE = "GPL-2.0-only & LGPL-2.1-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6 \
                    file://${COMMON_LICENSE_DIR}/LGPL-2.1-only;md5=1a6d268fd218675ffea8be556788b780"

INHIBIT_DEFAULT_DEPS = "1"

# Remove SPDX creation to avoid circular dependency
INHERIT:remove = "create-spdx create-spdx-3.0"

# Don't strip ARM binaries with x86 strip tool
INHIBIT_PACKAGE_STRIP = "1"
INHIBIT_SYSROOT_STRIP = "1"

# Disable patching since this is a pre-built toolchain
PATCHTOOL = "patch"
PATCH_DEPENDS = ""

SRC_URI = "git://github.com/LuckfoxTECH/luckfox-pico.git;protocol=https;branch=main"
SRCREV = "${AUTOREV}"

S = "${WORKDIR}/git"

inherit native

# Tell sysroot staging to include these directories
SYSROOT_DIRS += "${bindir}"
SYSROOT_DIRS += "${prefix}/arm-rockchip830-linux-uclibcgnueabihf"

TOOLCHAIN_PATH = "${S}/tools/linux/toolchain/arm-rockchip830-linux-uclibcgnueabihf"

# Skip tasks that would create circular dependencies
do_configure[noexec] = "1"
do_compile[noexec] = "1"
do_deploy_source_date_epoch[noexec] = "1"

# Delete do_prepare_recipe_sysroot to break circular dependency
# This toolchain doesn't need other recipes, so this is safe
deltask do_prepare_recipe_sysroot

do_install() {
    install -d ${D}${bindir}
    install -d ${D}${prefix}/arm-rockchip830-linux-uclibcgnueabihf
    
    # Copy the entire toolchain
    cp -a ${TOOLCHAIN_PATH}/* ${D}${prefix}/arm-rockchip830-linux-uclibcgnueabihf/
    
    # Create symlinks in bindir for the cross-tools
    cd ${D}${bindir}
    for tool in ${TOOLCHAIN_PATH}/bin/arm-rockchip830-linux-uclibcgnueabihf-*; do
        if [ -f "$tool" ]; then
            toolname=$(basename $tool)
            ln -sf ../arm-rockchip830-linux-uclibcgnueabihf/bin/$toolname $toolname
        fi
    done
}

# Provide environment setup for builds using this toolchain
# These are used at build time when recipes depend on this native package
EXTERNAL_TOOLCHAIN = "${STAGING_DIR_NATIVE}${prefix}/arm-rockchip830-linux-uclibcgnueabihf"

FILES:${PN} = "${bindir}/* ${prefix}/arm-rockchip830-linux-uclibcgnueabihf/*"
INSANE_SKIP:${PN} += "already-stripped ldflags file-rdeps arch"
