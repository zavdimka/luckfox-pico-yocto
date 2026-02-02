SUMMARY = "Luckfox Pico RV1106 U-Boot"
DESCRIPTION = "Rockchip 2017.09 U-Boot with Luckfox RV1106 settings and Rockchip loaders."
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://Licenses/gpl-2.0.txt;md5=b234ee4d69f5fce4486a80fdaf4a4263"

PV = "2017.09+luckfox"
PR = "r0"

SRC_URI = "git://github.com/LuckfoxTECH/luckfox-pico.git;protocol=https;branch=main;subpath=sysdrv/source/uboot/u-boot;destsuffix=git/u-boot;name=uboot \
           git://github.com/LuckfoxTECH/luckfox-pico.git;protocol=https;branch=main;subpath=sysdrv/source/uboot/rkbin;destsuffix=git/rkbin;name=rkbin \
           git://github.com/LuckfoxTECH/luckfox-pico.git;protocol=https;branch=main;subpath=sysdrv;destsuffix=git/sysdrv;name=sysdrv \
           file://0001-Luckfox-SDK-modifications-for-RV1106.patch \
"
SRCREV_uboot = "${AUTOREV}"
SRCREV_rkbin = "${AUTOREV}"
SRCREV_sysdrv = "${AUTOREV}"
SRCREV_FORMAT = "uboot_rkbin_sysdrv"
S = "${WORKDIR}/git/u-boot"
B = "${S}"

# Force in-tree builds - U-Boot 2017.09 doesn't properly support out-of-tree builds with Kbuild
# Override EXTRA_OEMAKE to remove O=${B} parameter
# Explicitly pass CROSS_COMPILE from luckfox-ext-toolchain
EXTRA_OEMAKE = ' \
    CROSS_COMPILE=${CROSS_COMPILE} \
    V=1 \
    HOSTCC="${BUILD_CC}" \
    STAGING_INCDIR=${STAGING_INCDIR_NATIVE} \
    STAGING_LIBDIR=${STAGING_LIBDIR_NATIVE} \
    -C ${S} \
'

require recipes-bsp/u-boot/u-boot.inc
inherit pkgconfig luckfox-ext-toolchain

DEPENDS += "bc-native u-boot-tools-native"

UBOOT_MACHINE = "luckfox_rv1106_uboot_defconfig"
UBOOT_ENTRYPOINT = "0x00200000"

COMPATIBLE_MACHINE = "luckfox-pico"

# Clean source tree and configure
do_configure() {
    cd ${S}
    
    # Clean old build artifacts manually (U-Boot 2017.09 Makefile has issues with directories)
    find . -name "*.o" -delete
    find . -name "*.a" -delete
    find . -name "*.so" -delete
    rm -rf spl/
    rm -rf u-boot-*-build/ || true
    
    # Clean but don't use mrproper (causes issues with in-tree builds)
    oe_runmake clean || true
    
    # Use the patched defconfig from our sources (includes SDK modifications)
    bbnote "Using patched luckfox_rv1106_uboot_defconfig"
    oe_runmake ${UBOOT_MACHINE}
    
    # Run oldconfig to resolve any dependencies
    oe_runmake oldconfig
}

# Build using SDK's sysdrv Makefile system (matches SDK build.sh)
do_compile() {
    # Use SDK components from WORKDIR (fetched via SRC_URI)
    SDK_SYSDRV_DIR="${WORKDIR}/git/sysdrv"
    SDK_RKBIN="${WORKDIR}/git/rkbin"
    RKBOOT_INI_DIR="${SDK_RKBIN}/RKBOOT"
    
    # Select INI file based on fastboot mode and boot medium (matching SDK logic)
    # Note: SPI NAND/NOR require specific SPL binaries even in normal (non-fastboot) mode
    if [ "${RK_ENABLE_FASTBOOT}" = "y" ]; then
        case ${RK_BOOT_MEDIUM} in
            emmc)
                RKBIN_INI="${RKBOOT_INI_DIR}/RV1106MINIALL_EMMC_TB.ini"
                ;;
            sd_card)
                # Note: SDK has a bug - it references RV1106MINIALL_SDMMC_TB.ini which doesn't exist
                # Fall back to standard INI for SD card fastboot
                bbnote "SD card fastboot not supported (_SDMMC_TB.ini doesn't exist), using standard INI"
                RKBIN_INI="${RKBOOT_INI_DIR}/RV1106MINIALL.ini"
                ;;
            spi_nor)
                RKBIN_INI="${RKBOOT_INI_DIR}/RV1106MINIALL_SPI_NOR_TB.ini"
                ;;
            spi_nand|slc_nand)
                RKBIN_INI="${RKBOOT_INI_DIR}/RV1106MINIALL_SPI_NAND_TB.ini"
                ;;
            *)
                bbfatal "Unsupported boot medium for fastboot: ${RK_BOOT_MEDIUM}"
                ;;
        esac
    else
        # Normal builds - select INI based on boot medium
        # SPI NAND/NOR need specific SPL binaries, SD/eMMC use standard
        case ${RK_BOOT_MEDIUM} in
            spi_nand|slc_nand)
                # RKBIN_INI="${RKBOOT_INI_DIR}/RV1106MINIALL_SPI_NAND_TB.ini"
                RKBIN_INI="${RKBOOT_INI_DIR}/RV1106MINIALL_SPI_NAND_TB_NOMCU.ini"
                ;;
            spi_nor)
                RKBIN_INI="${RKBOOT_INI_DIR}/RV1106MINIALL_SPI_NOR_TB.ini"
                ;;
            emmc|sd_card|*)
                RKBIN_INI="${RKBOOT_INI_DIR}/RV1106MINIALL.ini"
                ;;
        esac
    fi
    
    if [ ! -f "${RKBIN_INI}" ]; then
        bbfatal "RKBIN INI file not found: ${RKBIN_INI}"
    fi
    
    # Set up SDK directory structure for the build
    # The sysdrv Makefile expects u-boot source at source/uboot/u-boot
    mkdir -p ${SDK_SYSDRV_DIR}/source/uboot
    ln -sf ${S} ${SDK_SYSDRV_DIR}/source/uboot/u-boot
    ln -sf ${SDK_RKBIN} ${SDK_SYSDRV_DIR}/source/uboot/rkbin
    
    # Use SDK's make uboot command (matching build_uboot in build.sh)
    # This properly builds U-Boot with all SDK-specific configurations
    cd ${SDK_SYSDRV_DIR}
    
    # Unset SOURCE_DATE_EPOCH for proper build
    unset SOURCE_DATE_EPOCH
    
    # Set up environment for SDK build system
    # Toolchain is already in PATH via STAGING_BINDIR_NATIVE
    export CROSS_COMPILE="${EXTERNAL_TOOLCHAIN_PREFIX}"
    export ARCH="arm"
    
    # Get U-Boot config from machine definition (set in luckfox-pico.conf)
    UBOOT_CFG="${RK_UBOOT_DEFCONFIG}"
    UBOOT_CFG_FRAGMENT="${RK_UBOOT_DEFCONFIG_FRAGMENT}"

    bbplain "=== U-Boot Build Configuration ==="
    bbplain "Boot medium: ${RK_BOOT_MEDIUM}"
    bbplain "Fastboot mode: ${RK_ENABLE_FASTBOOT}"
    bbplain "Using RKBIN INI: ${RKBIN_INI}"
    bbplain "U-Boot config: ${UBOOT_CFG} + ${UBOOT_CFG_FRAGMENT}"
    
    # Call SDK's make uboot target with proper parameters
    # Pass HOSTCC as make parameter so it propagates through nested makes
    make uboot \
        HOSTCC="${BUILD_CC}" \
        UBOOT_CFG=${UBOOT_CFG} \
        UBOOT_CFG_FRAGMENT=${UBOOT_CFG_FRAGMENT} \
        SYSDRV_UBOOT_RKBIN_OVERLAY_INI=${RKBIN_INI} \
        || bbfatal "SDK make uboot failed"
    
    # Copy build artifacts from SDK build directory to ${S}
    # The SDK builds in ${SDK_SYSDRV_DIR}/source/uboot/u-boot (which is symlinked)
    # But files may not follow the symlink, so copy them explicitly
    cp -v ${SDK_SYSDRV_DIR}/source/uboot/u-boot/*.bin ${S}/ || true
    cp -v ${SDK_SYSDRV_DIR}/source/uboot/u-boot/*.img ${S}/ || true
    cp -v ${SDK_SYSDRV_DIR}/source/uboot/u-boot/*.dtb ${S}/ || true
    
    # Files are already in ${S} because we symlinked it
    # Just verify they exist
    bbplain "Files in U-Boot build directory:"
    ls -la ${S}/ | grep -E "(rv1106|uboot|u-boot)" || true
    
    # Verify critical files
    if [ ! -f ${S}/u-boot.bin ]; then
        bbfatal "u-boot.bin not found after build in ${S}"
    fi
    
    bbnote "U-Boot built successfully using SDK make system"
}

# Override do_install - U-Boot 2017.09 doesn't have u-boot-initial-env
do_install() {
    install -d ${D}/boot
    
    # Files should be in ${S} after the symlinked build
    if [ -f ${S}/u-boot.bin ]; then
        install -m 0644 ${S}/u-boot.bin ${D}/boot/u-boot.bin
    else
        bbfatal "u-boot.bin not found in ${S}"
    fi
    
    if [ -f ${S}/u-boot.dtb ]; then
        install -m 0644 ${S}/u-boot.dtb ${D}/boot/u-boot.dtb
    fi
}

# Override do_deploy completely for Rockchip RV1106
do_deploy() {
    install -d ${DEPLOYDIR}
    
    # Deploy u-boot.bin
    if [ -f ${S}/u-boot.bin ]; then
        install -m 0644 ${S}/u-boot.bin ${DEPLOYDIR}/u-boot.bin
        bbplain "Deployed: u-boot.bin"
    fi
    
    # Deploy Rockchip bootloader images from Yocto build
    # These are generated by the SDK make uboot system in the U-Boot source directory
    for download in ${S}/rv1106_download_v*.bin; do
        if [ -f "$download" ]; then
            install -m 0644 "$download" ${DEPLOYDIR}/download.bin
            bbplain "Deployed: download.bin ($(stat -c%s $download) bytes)"
        fi
    done
    
    for idblock in ${S}/rv1106_idblock_v*.img; do
        if [ -f "$idblock" ]; then
            install -m 0644 "$idblock" ${DEPLOYDIR}/idblock.img
            bbplain "Deployed: idblock.img ($(stat -c%s $idblock) bytes)"
        fi
    done
    
    # Deploy uboot.img - built by SDK make system  
    # SDK creates uboot.img (not u-boot.img)
    if [ -f ${S}/uboot.img ]; then
        install -m 0644 ${S}/uboot.img ${DEPLOYDIR}/uboot.img
        bbplain "Deployed: uboot.img ($(stat -c%s ${S}/uboot.img) bytes)"
    elif [ -f ${S}/u-boot.img ]; then
        install -m 0644 ${S}/u-boot.img ${DEPLOYDIR}/uboot.img
        bbplain "Deployed: uboot.img (from u-boot.img, $(stat -c%s ${S}/u-boot.img) bytes)"
    elif [ -f ${S}/u-boot-dtb.img ]; then
        install -m 0644 ${S}/u-boot-dtb.img ${DEPLOYDIR}/uboot.img
        bbplain "Deployed: uboot.img (from u-boot-dtb.img, $(stat -c%s ${S}/u-boot-dtb.img) bytes)"
    else
        bbfatal "No uboot.img/u-boot.img/u-boot-dtb.img found - SDK make uboot may have failed"
    fi
    
    # NOTE: env.img is now created by u-boot-env recipe
}

addtask deploy after do_install

FILES:${PN} = "/boot"
