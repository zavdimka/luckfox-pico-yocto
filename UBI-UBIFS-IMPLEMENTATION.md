# UBI/UBIFS Implementation for SPI NAND

## Overview

This document describes the UBI/UBIFS filesystem support implementation for the Luckfox Pico SPI NAND variant. The implementation matches the SDK's approach while using Yocto's native UBIFS image creation capabilities.

## What is UBI/UBIFS?

- **UBI** (Unsorted Block Images): A wear-leveling layer for raw NAND flash devices
- **UBIFS** (UBI File System): A log-structured filesystem designed for NAND flash, works on top of UBI
- **Why needed**: SPI NAND requires wear leveling and bad block management, which UBI provides

## Implementation Details

### 1. Machine Configuration (`luckfox-pico-spi-nand.conf`)

Added UBI/UBIFS parameters based on SPI NAND hardware specifications:

```bitbake
# NAND Hardware Parameters
RK_NAND_BLOCK_SIZE = "128K"    # Erase block size
RK_NAND_PAGE_SIZE = "2K"       # Page size
RK_NAND_OOB_SIZE = "128"       # Out-of-band data size

# UBIFS Parameters
# LEB (Logical Erase Block) = Block - 2*Page = 128K - 4K = 124K = 126976 bytes
# Min I/O = Page size = 2K = 2048 bytes
MKUBIFS_ARGS = "-m 2048 -e 126976 -c 2048 -x lzo"
UBINIZE_ARGS = "-m 2048 -p 131072"
UBI_VOLNAME = "rootfs"
```

**Parameter Explanation:**
- `-m 2048`: Minimum I/O unit size (page size)
- `-e 126976`: Logical erase block size (124K)
- `-c 2048`: Maximum LEB count (limits filesystem size)
- `-x lzo`: LZO compression for better performance
- `-p 131072`: Physical erase block size for ubinize (128K)

### 2. Partition Layout

```
RK_PARTITION_LAYOUT = "256K(env),256K@256K(idblock),512K(uboot),32M(boot),-(rootfs)"
RK_PARTITION_FS_TYPE = "rootfs@IGNORE@ubifs"
```

The rootfs partition uses UBIFS filesystem instead of ext4.

### 3. Boot Arguments

```
RK_BOOT_ROOT_ARGS = "ubi.mtd=4 root=ubi0:rootfs rootfstype=ubifs"
```

- `ubi.mtd=4`: Attach UBI to MTD partition 4 (rootfs, 5th partition, 0-indexed)
- `root=ubi0:rootfs`: Mount the "rootfs" UBI volume from ubi0 device
- `rootfstype=ubifs`: Use UBIFS filesystem driver

### 4. Image Creation (`rockchip-disk.bbclass`)

Modified to support both ext4 (eMMC/SD) and UBIFS (SPI NAND):

```bash
# Auto-detect filesystem type from RK_PARTITION_FS_TYPE
if echo "${RK_PARTITION_FS_TYPE}" | grep -q "rootfs@.*@ubifs"; then
    ROOTFS_FS_TYPE="ubifs"
    ROOTFS_IMG="${IMGDEPLOYDIR}/${IMAGE_LINK_NAME}.ubi"
else
    ROOTFS_FS_TYPE="ext4"
    ROOTFS_IMG="${IMGDEPLOYDIR}/${IMAGE_LINK_NAME}.ext4"
fi
```

The `.ubi` image is created by Yocto's native `ubinize` tool from the `.ubifs` image.

### 5. Build Dependencies

Added mtd-utils-native for mkfs.ubifs and ubinize tools:

```bitbake
do_image_rockchip_disk[depends] += "mtd-utils-native:do_populate_sysroot"

# Conditional UBIFS dependency
python() {
    if bb.utils.contains('MACHINE_FEATURES', 'ubifs', True, False, d):
        d.appendVarFlag('do_image_rockchip_disk', 'depends', ' ${PN}:do_image_ubifs')
}
```

## Kernel Support

UBI/UBIFS support is already enabled in the kernel configuration:

```
CONFIG_MTD_UBI=y
CONFIG_MTD_UBI_BLOCK=y
CONFIG_UBIFS_FS=y
CONFIG_UBIFS_FS_ADVANCED_COMPR=y
```

## Build Process

### Building for SPI NAND with UBIFS:

```bash
cd /home/dimka/luckfox-pico/yocto-walnascar/build-luckfox
MACHINE=luckfox-pico-spi-nand bitbake luckfox-image-minimal
```

### Generated Images:

1. **luckfox-image-minimal-luckfox-pico-spi-nand.rootfs.ubifs** - UBIFS filesystem image
2. **luckfox-image-minimal-luckfox-pico-spi-nand.rootfs.ubi** - UBI image (used in final disk)
3. **luckfox-image-minimal-luckfox-pico-spi-nand.rootfs.img** - Complete disk image with bootloader

## Boot Flow

1. **U-Boot**: Loads from SPI NAND (idblock + uboot partitions)
2. **Kernel**: Loaded from boot partition (FIT image)
3. **MTD Initialization**: Kernel detects SPI NAND as MTD device
4. **UBI Attach**: Kernel attaches UBI to MTD partition 4 (`ubi.mtd=4`)
5. **Volume Mount**: Mounts "rootfs" UBI volume as root (`root=ubi0:rootfs`)
6. **UBIFS**: UBIFS driver mounts the filesystem

## Comparison with SDK

The Yocto implementation achieves the same result as the SDK's `mkfs_ubi.sh` script:

| Aspect | SDK | Yocto |
|--------|-----|-------|
| mkfs.ubifs | Custom script | image_types.bbclass |
| ubinize | Custom script | image_types.bbclass |
| Parameters | Hardcoded in script | Machine config variables |
| Integration | Shell script | Native BitBake |
| Flexibility | Medium | High |

## Testing

### For ext4 Testing (temporary):

If you need to test with ext4 on MTD block device first:

```bitbake
RK_BOOT_ROOT_ARGS = "root=/dev/mtdblock4 rootfstype=ext4 rootwait"
IMAGE_FSTYPES = "ext4 rockchip-disk"
```

### For UBI/UBIFS Production:

Use the current configuration with proper UBI support.

## Troubleshooting

### Common Issues:

1. **"UBIFS error: cannot open UBI"**
   - Check `ubi.mtd=X` matches your partition index
   - Verify MTD partitions with `cat /proc/mtd`

2. **"VFS: Cannot open root device"**
   - Verify UBI volume name matches: `vol_name=rootfs`
   - Check boot arguments are correct

3. **Image size errors**
   - Adjust `-c` parameter in MKUBIFS_ARGS if filesystem is too large
   - Check available space in rootfs partition

### Debug Commands:

```bash
# On target device
cat /proc/mtd                    # Show MTD partitions
ubiattach -p /dev/mtd4          # Manually attach UBI
ubinfo -a                       # Show UBI information
mount -t ubifs ubi0:rootfs /mnt # Manually mount UBIFS
```

## References

- [Linux MTD FAQ - UBIFS](http://www.linux-mtd.infradead.org/faq/ubifs.html)
- [UBI Design](http://www.linux-mtd.infradead.org/doc/ubi.html)
- [Yocto image_types.bbclass](https://git.yoctoproject.org/poky/tree/meta/classes-recipe/image_types.bbclass)
- Rockchip SDK: `sysdrv/tools/pc/mtd-utils/mkfs_ubi.sh`
