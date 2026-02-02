SUMMARY = "U-Boot environment image for Luckfox Pico RV1106"
DESCRIPTION = "Creates env.img with U-Boot environment variables for Rockchip RV1106"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

DEPENDS = "u-boot-tools-native"

inherit deploy rockchip-partition

# U-Boot environment variables for Luckfox Pico
# blkdevparts is generated from ROCKCHIP_PARTITION_LAYOUT
UBOOT_ENV_BOOTARGS ?= "${RK_BOOT_ROOT_ARGS} console=${SERIAL_CONSOLE} rk_dma_heap_cma=1M"
UBOOT_ENV_BOOTCMD ?= "boot_fit"

do_compile() {
    # Get env size from partition layout (RK_PART_ENV_SIZE is in bytes)
    ENV_SIZE="${RK_PART_ENV_SIZE}"
    
    if [ -z "$ENV_SIZE" ]; then
        bbfatal "RK_PART_ENV_SIZE not set - ensure rockchip-partition.bbclass is inherited"
    fi
    
    # Create U-Boot environment text file with proper quoting
    # blkdevparts is dynamically generated from partition layout
    bbplain "${RK_BLKDEVPARTS}"
    bbplain "sys_bootargs= ${UBOOT_ENV_BOOTARGS}"
    bbplain "bootcmd= ${UBOOT_ENV_BOOTCMD}"
    bbplain "env size= $ENV_SIZE bytes"

    echo "${RK_BLKDEVPARTS}" > ${WORKDIR}/uboot-env.txt
    echo "bootcmd=${UBOOT_ENV_BOOTCMD}" >> ${WORKDIR}/uboot-env.txt
    echo "sys_bootargs=${UBOOT_ENV_BOOTARGS}" >> ${WORKDIR}/uboot-env.txt
    
    # Generate binary env.img using mkenvimage with size from partition layout
    mkenvimage -s $ENV_SIZE -o ${WORKDIR}/env.img ${WORKDIR}/uboot-env.txt
}

do_deploy() {
    install -d ${DEPLOYDIR}
    install -m 0644 ${WORKDIR}/env.img ${DEPLOYDIR}/env.img
}

addtask deploy after do_compile before do_build
