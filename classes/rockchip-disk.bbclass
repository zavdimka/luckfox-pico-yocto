# Class to create Rockchip RV1106 disk image with bootloader at fixed offsets
# This creates a complete disk image without partition table
# Partition layout is parsed from ROCKCHIP_PARTITION_LAYOUT

inherit image_types rockchip-partition

# Add rockchip-disk to supported image types
IMAGE_TYPES += "rockchip-disk"

# Size for the complete disk image (600MB)
RK_DISK_SIZE ??= "614400"

do_image_rockchip_disk[depends] += " \
    e2fsprogs-native:do_populate_sysroot \
    mtd-utils-native:do_populate_sysroot \
    u-boot-luckfox:do_deploy \
    u-boot-env:do_deploy \
"

# Ensure rootfs image is created before rockchip-disk
# For eMMC/SD use ext4, for SPI NAND use ubi (which includes ubifs)
do_image_rockchip_disk[depends] += "${PN}:do_image_ext4"
python() {
    # Add ubi dependency for SPI NAND builds (ubi image type includes ubifs)
    if bb.utils.contains('MACHINE_FEATURES', 'ubifs', True, False, d):
        d.appendVarFlag('do_image_rockchip_disk', 'depends', ' ${PN}:do_image_ubi')
        
        # Calculate UBI/UBIFS parameters based on NAND flash specs and partition size
        block_size = int(d.getVar('RK_NAND_BLOCK_SIZE') or '131072')  # Default 128K
        page_size = int(d.getVar('RK_NAND_PAGE_SIZE') or '2048')     # Default 2K
        
        # LEB (Logical Erase Block) size = Block size - 2 * Page size
        leb_size = block_size - (2 * page_size)
        
        # Get rootfs partition size to calculate max LEBs (-c option)
        rootfs_size = int(d.getVar('RK_PART_ROOTFS_SIZE') or '0')
        
        if rootfs_size > 0:
            # Calculate number of LEBs needed for the partition
            # Add 5% overhead for UBI metadata and wear-leveling
            max_lebs = int((rootfs_size / leb_size) * 1.05)
        else:
            # Fallback if partition size not available
            max_lebs = 2048
            bb.warn("RK_PART_ROOTFS_SIZE not available, using default max LEBs: %d" % max_lebs)
        
        # Set UBI/UBIFS parameters
        # -m: minimum I/O size (page size)
        # -e: LEB size
        # -c: max number of LEBs
        # -x: compression (lzo)
        mkubifs_args = "-m %d -e %d -c %d -x lzo" % (page_size, leb_size, max_lebs)
        
        # -m: minimum I/O size (page size)
        # -p: physical erase block size (block size)
        ubinize_args = "-m %d -p %d" % (page_size, block_size)
        
        d.setVar('MKUBIFS_ARGS', mkubifs_args)
        d.setVar('UBINIZE_ARGS', ubinize_args)
        d.setVar('UBI_VOLNAME', 'rootfs')
        
        bb.debug(1, "Calculated UBI parameters:")
        bb.debug(1, "  MKUBIFS_ARGS = %s" % mkubifs_args)
        bb.debug(1, "  UBINIZE_ARGS = %s" % ubinize_args)
        bb.debug(1, "  LEB size: %d bytes" % leb_size)
        bb.debug(1, "  Max LEBs: %d (for %d bytes partition)" % (max_lebs, rootfs_size))
}

# Create Rockchip disk image
IMAGE_CMD:rockchip-disk() {
    DEPLOY_DIR_IMAGE="${DEPLOY_DIR_IMAGE}"
    ROOTFS_DIR="${IMAGE_ROOTFS}"
    DISK_IMG="${IMGDEPLOYDIR}/${IMAGE_NAME}.img"
    
    # Get bootloader images
    ENV_IMG="${DEPLOY_DIR_IMAGE}/env.img"
    IDBLOCK_IMG="${DEPLOY_DIR_IMAGE}/idblock.img"
    UBOOT_IMG="${DEPLOY_DIR_IMAGE}/uboot.img"
    UBOOT_BIN="${DEPLOY_DIR_IMAGE}/u-boot.bin"
    
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
    if [ ! -f "$UBOOT_BIN" ]; then
        bbfatal "Required bootloader component not found: $UBOOT_BIN"
    fi
    
    bbnote "Found bootloader images:"
    bbnote "  env.img: $(stat -c%s $ENV_IMG) bytes"
    bbnote "  idblock.img: $(stat -c%s $IDBLOCK_IMG) bytes"
    bbnote "  u-boot.bin (source): $(stat -c%s $UBOOT_BIN) bytes"
    bbnote "  uboot.img (packaged): $(stat -c%s $UBOOT_IMG) bytes"
    
    # Get kernel boot.img (FIT image) - this is written directly to boot partition
    # boot_fit expects raw FIT image at partition start, not a filesystem!
    BOOT_IMG="${DEPLOY_DIR_IMAGE}/boot.img"
    
    # Verify boot.img exists
    if [ ! -f "$BOOT_IMG" ]; then
        bbfatal "Required boot image not found: $BOOT_IMG"
    fi
    
    bbnote "  boot.img: $(stat -c%s $BOOT_IMG) bytes"
    
    # Determine rootfs filesystem type from partition layout
    # Check RK_PART_ROOTFS_FSTYPE first (from partition layout name:fstype syntax)
    # Fall back to RK_PARTITION_FS_TYPE for backward compatibility
    ROOTFS_FS_TYPE="${RK_PART_ROOTFS_FSTYPE}"
    
    if [ -z "$ROOTFS_FS_TYPE" ] && echo "${RK_PARTITION_FS_TYPE}" | grep -q "rootfs@.*@ubifs"; then
        ROOTFS_FS_TYPE="ubifs"
    fi
    
    # Default to ext4 if not specified
    if [ -z "$ROOTFS_FS_TYPE" ]; then
        ROOTFS_FS_TYPE="ext4"
    fi
    
    bbplain "Rootfs filesystem type: $ROOTFS_FS_TYPE"
    
    # Use appropriate rootfs image based on filesystem type
    # For UBIFS on SPI NAND, use .ubi image (created by ubinize)
    # For ext4 on eMMC/SD, use .ext4 image
    if [ "$ROOTFS_FS_TYPE" = "ubifs" ]; then
        ROOTFS_IMG="${IMGDEPLOYDIR}/${IMAGE_LINK_NAME}.ubi"
    else
        ROOTFS_IMG="${IMGDEPLOYDIR}/${IMAGE_LINK_NAME}.ext4"
    fi
    
    # Verify rootfs exists
    if [ ! -f "$ROOTFS_IMG" ]; then
        bbfatal "Required rootfs image not found: $ROOTFS_IMG (filesystem type: $ROOTFS_FS_TYPE)"
    fi
    
    ROOTFS_SIZE=$(stat -L -c%s "$ROOTFS_IMG")
    bbplain "  rootfs.$ROOTFS_FS_TYPE: $ROOTFS_SIZE bytes"
    
    # Calculate disk image size based on partition layout
    # For A/B updates: need space for rootfs_a + rootfs_b + userdata (minimum 32MB)
    # For single boot: rootfs + userdata (minimum 32MB)
    # Use userdata offset if available, otherwise calculate from last partition
    
    if [ -n "${RK_PART_USERDATA_OFFSET}" ]; then
        # Userdata partition exists, use its offset + minimum size (32MB)
        USERDATA_MIN_SIZE=`expr 32 \* 1024 \* 1024 || true`  # 32MB minimum
        DISK_SIZE=`expr ${RK_PART_USERDATA_OFFSET} + $USERDATA_MIN_SIZE || true`
    elif [ "${RK_ENABLE_AB_UPDATE}" = "1" ] && [ -n "${RK_PART_ROOTFS_B_OFFSET}" ]; then
        # A/B mode without userdata: account for both rootfs partitions
        DISK_SIZE=`expr ${RK_PART_ROOTFS_B_OFFSET} + $ROOTFS_SIZE || true`
    else
        # Single partition mode: use first rootfs
        ROOTFS_OFFSET="${RK_PART_ROOTFS_OFFSET}"
        DISK_SIZE=`expr $ROOTFS_OFFSET + $ROOTFS_SIZE || true`
    fi
    
    DISK_SIZE_MB=`expr \( $DISK_SIZE + 1048575 \) / 1048576 || true`
    
    bbnote "Calculated disk image size: ${DISK_SIZE_MB}MB (A/B mode: ${RK_ENABLE_AB_UPDATE})"
    
    # Create base disk image (dynamic size based on partition layout)
    bbnote "Creating Rockchip RV1106 disk image (${DISK_SIZE_MB}MB)..."
    dd if=/dev/zero of=${DISK_IMG} bs=1M count=${DISK_SIZE_MB}
    
    # Write bootloader components using parsed partition offsets
    # Layout is dynamically calculated from RK_PARTITION_LAYOUT
    
    # Get partition offsets (in bytes, convert to sectors)
    ENV_OFFSET="${RK_PART_ENV_OFFSET}"
    IDBLOCK_OFFSET="${RK_PART_IDBLOCK_OFFSET}"
    UBOOT_OFFSET="${RK_PART_UBOOT_OFFSET}"
    
    # Handle A/B partition naming: use boot_a/rootfs_a if available, else boot/rootfs
    if [ -n "${RK_PART_BOOT_A_OFFSET}" ]; then
        BOOT_OFFSET="${RK_PART_BOOT_A_OFFSET}"
        BOOT_PART_SIZE="${RK_PART_BOOT_A_SIZE}"
    else
        BOOT_OFFSET="${RK_PART_BOOT_OFFSET}"
        BOOT_PART_SIZE="${RK_PART_BOOT_SIZE}"
    fi
    
    if [ -n "${RK_PART_ROOTFS_A_OFFSET}" ]; then
        ROOTFS_OFFSET="${RK_PART_ROOTFS_A_OFFSET}"
    else
        ROOTFS_OFFSET="${RK_PART_ROOTFS_OFFSET}"
    fi
    
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
    
    # Validate image sizes against partition sizes
    bbnote "Validating image sizes against partition layout..."
    
    # Get actual image sizes - check SOURCE binaries, not packaged images
    ENV_SIZE=$(stat -c%s "$ENV_IMG")
    IDBLOCK_SIZE=$(stat -c%s "$IDBLOCK_IMG")
    UBOOT_BIN_SIZE=$(stat -c%s "$UBOOT_BIN")
    UBOOT_IMG_SIZE=$(stat -c%s "$UBOOT_IMG")
    BOOT_SIZE=$(stat -c%s "$BOOT_IMG")
    
    # Get partition sizes (in bytes) - BOOT_PART_SIZE already set above based on A/B mode
    ENV_PART_SIZE="${RK_PART_ENV_SIZE}"
    IDBLOCK_PART_SIZE="${RK_PART_IDBLOCK_SIZE}"
    UBOOT_PART_SIZE="${RK_PART_UBOOT_SIZE}"
    
    # Check env.img size
    if [ $ENV_SIZE -gt $ENV_PART_SIZE ]; then
        bbfatal "env.img ($ENV_SIZE bytes) exceeds partition size ($ENV_PART_SIZE bytes, `expr $ENV_PART_SIZE / 1024`KB)"
    fi
    bbnote "  env.img: $ENV_SIZE bytes / $ENV_PART_SIZE bytes (`expr $ENV_SIZE \* 100 / $ENV_PART_SIZE`% used)"
    
    # Check idblock.img size
    if [ $IDBLOCK_SIZE -gt $IDBLOCK_PART_SIZE ]; then
        bbfatal "idblock.img ($IDBLOCK_SIZE bytes) exceeds partition size ($IDBLOCK_PART_SIZE bytes, `expr $IDBLOCK_PART_SIZE / 1024`KB)"
    fi
    bbnote "  idblock.img: $IDBLOCK_SIZE bytes / $IDBLOCK_PART_SIZE bytes (`expr $IDBLOCK_SIZE \* 100 / $IDBLOCK_PART_SIZE`% used)"
    
    # Check uboot.img size (the packed image, not raw u-boot.bin)
    # uboot.img is created by SDK's boot_merger tool and is the actual bootloader image
    if [ $UBOOT_IMG_SIZE -gt $UBOOT_PART_SIZE ]; then
        bbfatal "uboot.img ($UBOOT_IMG_SIZE bytes, `expr $UBOOT_IMG_SIZE / 1024`KB) exceeds U-Boot partition size ($UBOOT_PART_SIZE bytes, `expr $UBOOT_PART_SIZE / 1024`KB). Increase uboot partition size in RK_PARTITION_LAYOUT."
    fi
    
    # Warn if u-boot.bin is significantly larger than partition (informational only)
    # This is normal - uboot.img is packed/compressed from u-boot.bin
    if [ $UBOOT_BIN_SIZE -gt $UBOOT_PART_SIZE ]; then
        SIZE_DIFF_KB=`expr \( $UBOOT_BIN_SIZE - $UBOOT_PART_SIZE \) / 1024 || true`
        bbnote "Note: u-boot.bin ($UBOOT_BIN_SIZE bytes) is larger than partition, but uboot.img ($UBOOT_IMG_SIZE bytes) fits. This is normal - uboot.img is packed/compressed."
    fi
    
    bbnote "  uboot.img: $UBOOT_IMG_SIZE bytes / $UBOOT_PART_SIZE bytes (`expr $UBOOT_IMG_SIZE \* 100 / $UBOOT_PART_SIZE`% used)"
    
    # Check boot.img size
    if [ $BOOT_SIZE -gt $BOOT_PART_SIZE ]; then
        bbfatal "boot.img ($BOOT_SIZE bytes) exceeds partition size ($BOOT_PART_SIZE bytes, `expr $BOOT_PART_SIZE / 1024 / 1024`MB)"
    fi
    bbnote "  boot.img: $BOOT_SIZE bytes / $BOOT_PART_SIZE bytes (`expr $BOOT_SIZE \* 100 / $BOOT_PART_SIZE`% used)"
    
    bbnote "All images fit within their partitions."
    
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
    
    # A/B Update: Duplicate boot and rootfs partitions if enabled
    if [ "${RK_ENABLE_AB_UPDATE}" = "1" ]; then
        bbnote "A/B Update enabled - duplicating partitions..."
        
        # Duplicate boot_a to boot_b
        if [ -n "${RK_PART_BOOT_B_OFFSET}" ]; then
            BOOT_B_SECTOR=`expr ${RK_PART_BOOT_B_OFFSET} / 512 || true`
            bbnote "Duplicating boot_a to boot_b at sector $BOOT_B_SECTOR"
            dd if=${BOOT_IMG} of=${DISK_IMG} seek=$BOOT_B_SECTOR bs=512 conv=notrunc
        fi
        
        # Duplicate rootfs_a to rootfs_b
        if [ -n "${RK_PART_ROOTFS_B_OFFSET}" ]; then
            ROOTFS_B_SECTOR=`expr ${RK_PART_ROOTFS_B_OFFSET} / 512 || true`
            bbnote "Duplicating rootfs_a to rootfs_b at sector $ROOTFS_B_SECTOR"
            dd if=${ROOTFS_IMG} of=${DISK_IMG} seek=$ROOTFS_B_SECTOR bs=512 conv=notrunc
        fi
        
        bbnote "A/B partition duplication complete"
    fi
    
    bbnote "Rockchip disk image created: ${DISK_IMG} (${DISK_SIZE_MB}MB total)"
    
    # Generate partition layout documentation
    LAYOUT_DOC="${IMGDEPLOYDIR}/${IMAGE_NAME}-layout.txt"
    
    # Get image sizes (already retrieved above for validation)
    ROOTFS_SIZE=$(stat -c%s "$ROOTFS_IMG")
    TOTAL_SIZE=$(stat -c%s "$DISK_IMG")
    
    # Format sizes in human-readable format
    ENV_SIZE_KB=`expr $ENV_SIZE / 1024 || true`
    IDBLOCK_SIZE_KB=`expr $IDBLOCK_SIZE / 1024 || true`
    UBOOT_IMG_SIZE_KB=`expr $UBOOT_IMG_SIZE / 1024 || true`
    UBOOT_BIN_SIZE_KB=`expr $UBOOT_BIN_SIZE / 1024 || true`
    BOOT_SIZE_KB=`expr $BOOT_SIZE / 1024 || true`
    ROOTFS_SIZE_MB=`expr $ROOTFS_SIZE / 1048576 || true`
    TOTAL_SIZE_MB=`expr $TOTAL_SIZE / 1048576 || true`
    
    # Get partition sizes from variables
    ENV_PART_SIZE="${RK_PART_ENV_SIZE}"
    IDBLOCK_PART_SIZE="${RK_PART_IDBLOCK_SIZE}"
    UBOOT_PART_SIZE="${RK_PART_UBOOT_SIZE}"
    BOOT_PART_SIZE="${RK_PART_BOOT_SIZE}"
    
    # Convert partition sizes to KB/MB
    ENV_PART_SIZE_KB=`expr $ENV_PART_SIZE / 1024 || true`
    IDBLOCK_PART_SIZE_KB=`expr $IDBLOCK_PART_SIZE / 1024 || true`
    UBOOT_PART_SIZE_KB=`expr $UBOOT_PART_SIZE / 1024 || true`
    BOOT_PART_SIZE_MB=`expr $BOOT_PART_SIZE / 1048576 || true`
    
    bbnote "Generating partition layout documentation: ${LAYOUT_DOC}"
    
    cat > ${LAYOUT_DOC} << EOF
================================================================================
Rockchip RV1106 Disk Image Layout Documentation
================================================================================
Generated: $(date)
Image: ${IMAGE_NAME}.img
Layout: ${ROCKCHIP_PARTITION_LAYOUT}
Boot Medium: ${ROCKCHIP_BOOT_MEDIUM}

================================================================================
PARTITION TABLE
================================================================================

Partition    | Address (Hex) | Address (Dec) | Size (Bytes)  | Size (Human)  | Image Size
-------------|---------------|---------------|---------------|---------------|--------------
env          | 0x$(printf '%08x' $ENV_OFFSET)    | $ENV_OFFSET       | $ENV_PART_SIZE        | ${ENV_PART_SIZE_KB} KB       | ${ENV_SIZE_KB} KB
idblock      | 0x$(printf '%08x' $IDBLOCK_OFFSET)    | $IDBLOCK_OFFSET       | $IDBLOCK_PART_SIZE        | ${IDBLOCK_PART_SIZE_KB} KB      | ${IDBLOCK_SIZE_KB} KB
uboot        | 0x$(printf '%08x' $UBOOT_OFFSET)    | $UBOOT_OFFSET       | $UBOOT_PART_SIZE        | ${UBOOT_PART_SIZE_KB} KB      | ${UBOOT_SIZE_KB} KB
boot         | 0x$(printf '%08x' $BOOT_OFFSET)    | $BOOT_OFFSET      | $BOOT_PART_SIZE       | ${BOOT_PART_SIZE_MB} MB        | ${BOOT_SIZE_KB} KB
rootfs       | 0x$(printf '%08x' $ROOTFS_OFFSET)    | $ROOTFS_OFFSET     | $ROOTFS_SIZE      | ${ROOTFS_SIZE_MB} MB       | ${ROOTFS_SIZE_MB} MB

================================================================================
IMAGE DETAILS
================================================================================

1. ENV Partition (U-Boot Environment)
   Source Image:    ${ENV_IMG}
   Original Size:   ${ENV_SIZE} bytes (${ENV_SIZE_KB} KB)
   Partition Size:  ${ENV_PART_SIZE} bytes (${ENV_PART_SIZE_KB} KB)
   Start Address:   0x$(printf '%08x' $ENV_OFFSET) ($ENV_OFFSET bytes)
   Sector:          $ENV_SECTOR
   
2. IDBLOCK Partition (Bootloader ID Block)
   Source Image:    ${IDBLOCK_IMG}
   Original Size:   ${IDBLOCK_SIZE} bytes (${IDBLOCK_SIZE_KB} KB)
   Partition Size:  ${IDBLOCK_PART_SIZE} bytes (${IDBLOCK_PART_SIZE_KB} KB)
   Start Address:   0x$(printf '%08x' $IDBLOCK_OFFSET) ($IDBLOCK_OFFSET bytes)
   Sector:          $IDBLOCK_SECTOR
   
3. U-BOOT Partition (U-Boot Proper)
   Source Image:    ${UBOOT_IMG}
   Original Size:   ${UBOOT_IMG_SIZE} bytes (${UBOOT_IMG_SIZE_KB} KB)
   U-Boot Binary:   ${UBOOT_BIN_SIZE} bytes (${UBOOT_BIN_SIZE_KB} KB)
   Partition Size:  ${UBOOT_PART_SIZE} bytes (${UBOOT_PART_SIZE_KB} KB)
   Start Address:   0x$(printf '%08x' $UBOOT_OFFSET) ($UBOOT_OFFSET bytes)
   Sector:          $UBOOT_SECTOR
   
4. BOOT Partition (Kernel FIT Image)
   Source Image:    ${BOOT_IMG}
   Original Size:   ${BOOT_SIZE} bytes (${BOOT_SIZE_KB} KB)
   Partition Size:  ${BOOT_PART_SIZE} bytes (${BOOT_PART_SIZE_MB} MB)
   Start Address:   0x$(printf '%08x' $BOOT_OFFSET) ($BOOT_OFFSET bytes)
   Sector:          $BOOT_SECTOR
   
5. ROOTFS Partition (Root Filesystem - $ROOTFS_FS_TYPE)
   Source Image:    ${ROOTFS_IMG}
   Original Size:   ${ROOTFS_SIZE} bytes (${ROOTFS_SIZE_MB} MB)
   Partition Size:  Variable (fills remaining space)
   Start Address:   0x$(printf '%08x' $ROOTFS_OFFSET) ($ROOTFS_OFFSET bytes)
   Sector:          $ROOTFS_SECTOR

================================================================================
DISK IMAGE SUMMARY
================================================================================

Total Disk Size: ${TOTAL_SIZE} bytes (${TOTAL_SIZE_MB} MB)
Used Space:      $DISK_SIZE bytes (${DISK_SIZE_MB} MB)

Partition Layout String: ${ROCKCHIP_PARTITION_LAYOUT}

U-Boot Arguments: ${RK_BLKDEVPARTS}

================================================================================
EOF
    
    bbnote "Partition layout documentation created: ${LAYOUT_DOC}"
    
    # Create symlink for layout doc
    ln -sf ${IMAGE_NAME}-layout.txt ${IMGDEPLOYDIR}/${IMAGE_LINK_NAME}-layout.txt
    
    # Create symlink for disk image
    ln -sf ${IMAGE_NAME}.img ${IMGDEPLOYDIR}/${IMAGE_LINK_NAME}.img
}
