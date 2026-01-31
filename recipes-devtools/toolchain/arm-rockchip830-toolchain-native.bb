SUMMARY = "Rockchip ARM toolchain (GCC 8.3.0 + uclibc)"
DESCRIPTION = "External ARM toolchain from Luckfox SDK for RV1106"
LICENSE = "GPL-2.0-only & LGPL-2.1-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6 \
                    file://${COMMON_LICENSE_DIR}/LGPL-2.1-only;md5=1a6d268fd218675ffea8be556788b780"

INHIBIT_DEFAULT_DEPS = "1"

# Remove SPDX creation to avoid circular dependency
INHERIT:remove = "create-spdx create-spdx-3.0"

# Disable patching since this is a pre-built toolchain
PATCHTOOL = "patch"
PATCH_DEPENDS = ""

SRC_URI = "git://github.com/LuckfoxTECH/luckfox-pico.git;protocol=https;branch=main"
SRCREV = "${AUTOREV}"

S = "${WORKDIR}/git"

inherit native

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
    
    # Create relative symlinks in bindir for the cross-tools
    # Relative path from bindir to the toolchain bin directory
    cd ${D}${bindir}
    for tool in ${TOOLCHAIN_PATH}/bin/arm-rockchip830-linux-uclibcgnueabihf-*; do
        if [ -f "$tool" ]; then
            toolname=$(basename $tool)
            ln -s ../arm-rockchip830-linux-uclibcgnueabihf/bin/$toolname $toolname
        fi
    done
}

# Provide environment setup for builds using this toolchain
export EXTERNAL_TOOLCHAIN = "${STAGING_DIR_NATIVE}${prefix}/arm-rockchip830-linux-uclibcgnueabihf"
export PATH:prepend = "${EXTERNAL_TOOLCHAIN}/bin:"
export CC = "arm-rockchip830-linux-uclibcgnueabihf-gcc"
export CXX = "arm-rockchip830-linux-uclibcgnueabihf-g++"
export CPP = "arm-rockchip830-linux-uclibcgnueabihf-gcc -E"
export LD = "arm-rockchip830-linux-uclibcgnueabihf-ld"
export AR = "arm-rockchip830-linux-uclibcgnueabihf-ar"
export AS = "arm-rockchip830-linux-uclibcgnueabihf-as"
export RANLIB = "arm-rockchip830-linux-uclibcgnueabihf-ranlib"
export OBJCOPY = "arm-rockchip830-linux-uclibcgnueabihf-objcopy"
export OBJDUMP = "arm-rockchip830-linux-uclibcgnueabihf-objdump"
export STRIP = "arm-rockchip830-linux-uclibcgnueabihf-strip"

FILES:${PN} = "${bindir}/* ${prefix}/arm-rockchip830-linux-uclibcgnueabihf/*"
INSANE_SKIP:${PN} += "already-stripped ldflags file-rdeps arch"
