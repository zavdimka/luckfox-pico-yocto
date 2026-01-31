# Class to create Rockchip RV1106 disk image with bootloader at fixed offsets
# This creates a complete disk image without partition table
# Partition layout is parsed from ROCKCHIP_PARTITION_LAYOUT

inherit image_types rockchip-partition

# Add rockchip-disk to supported image types
IMAGE_TYPES += "rockchip-disk"

# Size for the complete disk image (600MB)
ROCKCHIP_DISK_SIZE ??= "614400"

do_image_rockchip_disk[depends] += " \
    e2fsprogs-native:do_populate_sysroot \
    u-boot-luckfox:do_deploy \
    u-boot-env:do_deploy \
"

# Ensure ext4 image is created before rockchip-disk
do_image_rockchip_disk[depends] += "${PN}:do_image_ext4"

# Create Rockchip disk image
IMAGE_CMD:rockchip-disk() {
    DEPLOY_DIR_IMAGE="${DEPLOY_DIR_IMAGE}"
    ROOTFS_DIR="${IMAGE_ROOTFS}"
    DISK_IMG="${IMGDEPLOYDIR}/${IMAGE_NAME}.img"
    
    # Get bootloader images
    ENV_IMG="${DEPLOY_DIR_IMAGE}/env.img"
    IDBLOCK_IMG="${DEPLOY_DIR_IMAGE}/idblock.img"
    UBOOT_IMG="${DEPLOY_DIR_IMAGE}/uboot.img"
    
    # Verify bootloader components exist
    if [ ! -f "$ENV_IMG" ]; then
        bbfatal "Required bootloader component not found: $ENV_IMG"
    fi
    if [ ! -f "$IDBLOCK_IMG" ]; then
        bbfatal "Required bootloader component not found: $IDBLOCK_IMG"
    fi
    if [ ! -f "$UBOOT_IMG" ]; then
        bbfatal "Required bootloader component not found: $UBOOT_IMG"
    fi
    
    bbnote "Found bootloader images:"
    bbnote "  env.img: $(stat -c%s $ENV_IMG) bytes"
    bbnote "  idblock.img: $(stat -c%s $IDBLOCK_IMG) bytes"
    bbnote "  uboot.img: $(stat -c%s $UBOOT_IMG) bytes"
    
    # Get kernel boot.img (FIT image) - this is written directly to boot partition
    # boot_fit expects raw FIT image at partition start, not a filesystem!
    BOOT_IMG="${DEPLOY_DIR_IMAGE}/boot.img"
    
    # Verify boot.img exists
    if [ ! -f "$BOOT_IMG" ]; then
        bbfatal "Required boot image not found: $BOOT_IMG"
    fi
    
    bbnote "  boot.img: $(stat -c%s $BOOT_IMG) bytes"
    
    # Use Yocto's standard ext4 rootfs image (created by do_image_ext4)
    # IMAGE_LINK_NAME already includes ".rootfs"
    ROOTFS_IMG="${IMGDEPLOYDIR}/${IMAGE_LINK_NAME}.ext4"
    
    # Verify rootfs exists
    if [ ! -f "$ROOTFS_IMG" ]; then
        bbfatal "Required rootfs image not found: $ROOTFS_IMG"
    fi
    
    ROOTFS_SIZE=$(stat -c%s "$ROOTFS_IMG")
    bbnote "  rootfs.ext4: $ROOTFS_SIZE bytes"
    
    # Calculate disk image size (rootfs offset + rootfs size, rounded up)
    ROOTFS_OFFSET="${ROCKCHIP_PART_ROOTFS_OFFSET}"
    DISK_SIZE=`expr $ROOTFS_OFFSET + $ROOTFS_SIZE || true`
    DISK_SIZE_MB=`expr \( $DISK_SIZE + 1048575 \) / 1048576 || true`
    
    # Create base disk image (dynamic size based on rootfs)
    bbnote "Creating Rockchip RV1106 disk image (${DISK_SIZE_MB}MB)..."
    dd if=/dev/zero of=${DISK_IMG} bs=1M count=${DISK_SIZE_MB}
    
    # Write bootloader components using parsed partition offsets
    # Layout is dynamically calculated from ROCKCHIP_PARTITION_LAYOUT
    
    # Get partition offsets (in bytes, convert to sectors)
    ENV_OFFSET="${ROCKCHIP_PART_ENV_OFFSET}"
    IDBLOCK_OFFSET="${ROCKCHIP_PART_IDBLOCK_OFFSET}"
    UBOOT_OFFSET="${ROCKCHIP_PART_UBOOT_OFFSET}"
    BOOT_OFFSET="${ROCKCHIP_PART_BOOT_OFFSET}"
    ROOTFS_OFFSET="${ROCKCHIP_PART_ROOTFS_OFFSET}"
    
    # Convert bytes to 512-byte sectors
    ENV_SECTOR=`expr $ENV_OFFSET / 512 || true`
    IDBLOCK_SECTOR=`expr $IDBLOCK_OFFSET / 512 || true`
    UBOOT_SECTOR=`expr $UBOOT_OFFSET / 512 || true`
    BOOT_SECTOR=`expr $BOOT_OFFSET / 512 || true`
    ROOTFS_SECTOR=`expr $ROOTFS_OFFSET / 512 || true`
    
    bbnote "Partition layout (from ROCKCHIP_PARTITION_LAYOUT):"
    bbnote "  env:     sector $ENV_SECTOR (`expr $ENV_OFFSET / 1024 || true`KB)"
    bbnote "  idblock: sector $IDBLOCK_SECTOR (`expr $IDBLOCK_OFFSET / 1024 || true`KB)"
    bbnote "  uboot:   sector $UBOOT_SECTOR (`expr $UBOOT_OFFSET / 1024 || true`KB)"
    bbnote "  boot:    sector $BOOT_SECTOR (`expr $BOOT_OFFSET / 1024 || true`KB)"
    bbnote "  rootfs:  sector $ROOTFS_SECTOR (`expr $ROOTFS_OFFSET / 1024 / 1024 || true`MB)"
    
    bbnote "Writing env.img at sector $ENV_SECTOR"
    dd if=${ENV_IMG} of=${DISK_IMG} seek=$ENV_SECTOR bs=512 conv=notrunc
    
    bbnote "Writing idblock.img at sector $IDBLOCK_SECTOR"
    dd if=${IDBLOCK_IMG} of=${DISK_IMG} seek=$IDBLOCK_SECTOR bs=512 conv=notrunc
    
    bbnote "Writing uboot.img at sector $UBOOT_SECTOR"
    dd if=${UBOOT_IMG} of=${DISK_IMG} seek=$UBOOT_SECTOR bs=512 conv=notrunc
    
    bbnote "Writing boot partition at sector $BOOT_SECTOR"
    dd if=${BOOT_IMG} of=${DISK_IMG} seek=$BOOT_SECTOR bs=512 conv=notrunc
    
    bbnote "Writing rootfs partition at sector $ROOTFS_SECTOR"
    dd if=${ROOTFS_IMG} of=${DISK_IMG} seek=$ROOTFS_SECTOR bs=512 conv=notrunc
    
    bbnote "Rockchip disk image created: ${DISK_IMG} (${DISK_SIZE_MB}MB total)"
    
    # Create symlink
    ln -sf ${IMAGE_NAME}.img ${IMGDEPLOYDIR}/${IMAGE_LINK_NAME}.img
}
