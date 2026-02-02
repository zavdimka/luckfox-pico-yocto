SUMMARY = "Luckfox Pico RV1106 Linux kernel"
DESCRIPTION = "Linux 5.10.160 with Luckfox RV1106 defconfig and DTS"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://COPYING;md5=6bc538ed5bd9a7fc9398086aedcd7e46"

PV = "5.10.160"
PR = "r0"

SRC_URI = " \
    git://github.com/LuckfoxTECH/luckfox-pico.git;protocol=https;branch=main \
    file://${KERNEL_DTS_FILE} \
    file://sdk-kernel.config \
    file://rv1106-bt.config \
    file://luckfox_rv1106-wwan-ndis-ppp.config \
    file://usb-gadget.config \
    file://wifi.cfg \
"

SRCREV = "${AUTOREV}"
S = "${WORKDIR}/git/sysdrv/source/kernel"
# Use separate build directory - kernel class requires it
# B defaults to ${WORKDIR}/build which is fine

# Override shared kernel source location
STAGING_KERNEL_DIR = "${WORKDIR}/git/sysdrv/source/kernel"

inherit kernel luckfox-ext-toolchain

DEPENDS += "bc-native"

KERNEL_IMAGETYPE = "Image"
# Auto-derive DTB name from DTS file specified in machine config
KERNEL_DEVICETREE = "${@d.getVar('KERNEL_DTS_FILE').replace('.dts', '.dtb')}"

KBUILD_DEFCONFIG = "rv1106_defconfig"
KERNEL_CONFIG_FRAGMENTS += "${WORKDIR}/sources-unpack/sdk-kernel.config ${WORKDIR}/sources-unpack/rv1106-bt.config ${WORKDIR}/sources-unpack/luckfox_rv1106-wwan-ndis-ppp.config ${WORKDIR}/sources-unpack/usb-gadget.config ${WORKDIR}/sources-unpack/wifi.cfg"

COMPATIBLE_MACHINE = "luckfox-pico|luckfox-pico-sd|luckfox-pico-spi-nand|luckfox-pico-spi-nor"

# Skip buildpaths QA check - external toolchain may embed TMPDIR paths
INSANE_SKIP:kernel-dbg += "buildpaths"

# Override do_configure to use external Rockchip toolchain
do_configure() {
    # Toolchain is already in PATH via STAGING_BINDIR_NATIVE (symlinks from toolchain-native)
    export CROSS_COMPILE="${EXTERNAL_TOOLCHAIN_PREFIX}"
    export ARCH="arm"
    
    # Copy custom DTS file to kernel source tree
    if [ -f "${WORKDIR}/sources-unpack/${KERNEL_DTS_FILE}" ]; then
        cp -f ${WORKDIR}/sources-unpack/${KERNEL_DTS_FILE} ${S}/arch/arm/boot/dts/
    fi
    
    # Run defconfig with out-of-tree build
    make -C ${S} O=${B} ${KBUILD_DEFCONFIG}
    
    # Merge config fragments if any
    if [ -n "${KERNEL_CONFIG_FRAGMENTS}" ]; then
        for fragment in ${KERNEL_CONFIG_FRAGMENTS}; do
            if [ -f "$fragment" ]; then
                ${S}/scripts/kconfig/merge_config.sh -m -r ${B}/.config $fragment
            fi
        done
    fi
}

# Override do_compile to use external Rockchip toolchain
# The kernel class applies Yocto's CC/CROSS_COMPILE which forces GCC 14
do_compile() {
    # Use toolchain from SDK directly
    export PATH="${EXTERNAL_TOOLCHAIN_BIN}:$PATH"
    export CROSS_COMPILE="${EXTERNAL_TOOLCHAIN_PREFIX}"
    export ARCH="arm"
    
    # Kernel 5.10 scripts may use 'python' instead of 'python3'
    # Create a wrapper script if python doesn't exist
    if ! command -v python >/dev/null 2>&1; then
        mkdir -p ${WORKDIR}/python-wrapper
        ln -sf $(command -v python3) ${WORKDIR}/python-wrapper/python
        export PATH="${WORKDIR}/python-wrapper:$PATH"
    fi
    
    # Build kernel with external toolchain (out-of-tree)
    unset CFLAGS CPPFLAGS CXXFLAGS LDFLAGS
    make -C ${S} O=${B} -j ${@oe.utils.parallel_make(d)} \
        HOSTCC="${BUILD_CC}" \
        HOSTCPP="${BUILD_CPP}" \
        KBUILD_BUILD_USER="oe-user" \
        KBUILD_BUILD_HOST="oe-host" \
        ${KERNEL_IMAGETYPE} modules dtbs
}

# Override do_compile_kernelmodules - kernel class splits this out
do_compile_kernelmodules() {
    :
}

# Ensure the kernel build Makefile is available for module builds
# The kernel.bbclass stages headers and symbols but not all config files
do_shared_workdir:append() {
    # Copy the kernel build Makefile
    if [ -f "${B}/Makefile" ]; then
        install -m 0644 ${B}/Makefile ${STAGING_KERNEL_BUILDDIR}/
    fi
    
    # Copy include/config directory with auto.conf and other generated configs
    if [ -d "${B}/include/config" ]; then
        install -d ${STAGING_KERNEL_BUILDDIR}/include/config
        cp -r ${B}/include/config/* ${STAGING_KERNEL_BUILDDIR}/include/config/
    fi
    
    # Copy include/generated directory
    if [ -d "${B}/include/generated" ]; then
        install -d ${STAGING_KERNEL_BUILDDIR}/include/generated
        cp -r ${B}/include/generated/* ${STAGING_KERNEL_BUILDDIR}/include/generated/
    fi
    
    # Copy .config file
    if [ -f "${B}/.config" ]; then
        install -m 0644 ${B}/.config ${STAGING_KERNEL_BUILDDIR}/
    fi
}
