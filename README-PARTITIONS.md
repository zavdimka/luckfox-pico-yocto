# Rockchip Partition Layout System

This Yocto layer uses the same partition layout approach as the Luckfox SDK, making it easy to port configurations.

## Partition Layout Format

The partition layout is defined using the SDK-compatible format:

```
size@offset(name),size@offset(name),...
```

Where:
- **size**: Partition size with unit suffix (K, M, G, T) or `-` for remaining space
- **offset**: Optional starting offset (auto-calculated if omitted)  
- **name**: Partition name

### Example

```bitbake
ROCKCHIP_PARTITION_LAYOUT = "32K(env),512K@32K(idblock),256K(uboot),32M(boot),-(rootfs)"
```

This creates:
- `env`: 32KB at sector 0
- `idblock`: 512KB at 32KB offset  
- `uboot`: 256KB at 544KB offset
- `boot`: 32MB at 800KB offset
- `rootfs`: Remaining space (variable size)

## Building for Different Boot Media

### eMMC (default)

```bash
MACHINE=luckfox-pico bitbake luckfox-image-minimal
```

Creates image for eMMC (mmcblk0)

### SD Card

```bash
MACHINE=luckfox-pico-sd bitbake luckfox-image-minimal
```

Creates image for SD card (mmcblk1)

### SPI NAND

```bash
MACHINE=luckfox-pico-spi-nand bitbake luckfox-image-minimal
```

Creates image for SPI NAND flash (mtd devices, UBI filesystem)

## Machine Configuration

### Base Machine (luckfox-pico.conf)

```bitbake
# Default boot medium
ROCKCHIP_BOOT_MEDIUM = "emmc"

# Partition layout (shared by all variants)
ROCKCHIP_PARTITION_LAYOUT = "32K(env),512K@32K(idblock),256K(uboot),32M(boot),-(rootfs)"
```

### SD Card Variant (luckfox-pico-sd.conf)

```bitbake
require conf/machine/luckfox-pico.conf

# Override for SD card
RK_BOOT_MEDIUM = "sd_card"
ROCKCHIP_BOOT_MEDIUM = "${RK_BOOT_MEDIUM}"
```

### SPI NAND Variant (luckfox-pico-spi-nand.conf)

```bitbake
require conf/machine/luckfox-pico.conf

# Override for SPI NAND
RK_BOOT_MEDIUM = "spi_nand"
ROCKCHIP_BOOT_MEDIUM = "${RK_BOOT_MEDIUM}"

# NAND-specific parameters
RK_NAND_BLOCK_SIZE ?= "0x20000"
RK_NAND_PAGE_SIZE ?= "2048"
RK_NAND_OOB_SIZE ?= "128"
```

### SPI NOR Variant (luckfox-pico-spi-nor.conf)

```bitbake
require conf/machine/luckfox-pico.conf

# Override for SPI NOR
RK_BOOT_MEDIUM = "spi_nor"
ROCKCHIP_BOOT_MEDIUM = "${RK_BOOT_MEDIUM}"

# Typically smaller partition layout for limited NOR capacity
ROCKCHIP_PARTITION_LAYOUT = "32K(env),512K@32K(idblock),256K(uboot),4M(boot),-(rootfs)"
```

## Custom Partition Layouts

Override in your `local.conf` or custom machine config:

```bitbake
# Larger boot partition for multiple kernels
ROCKCHIP_PARTITION_LAYOUT = "32K(env),512K@32K(idblock),256K(uboot),64M(boot),-(rootfs)"

# Separate OEM and userdata partitions
ROCKCHIP_PARTITION_LAYOUT = "32K(env),512K@32K(idblock),256K(uboot),32M(boot),4G(rootfs),512M(oem),-(userdata)"
```

## How It Works

1. **rockchip-partition.bbclass** - Parses `ROCKCHIP_PARTITION_LAYOUT`
   - Converts size strings to bytes
   - Calculates offsets automatically
   - Exports variables like `ROCKCHIP_PART_BOOT_OFFSET`

2. **u-boot-env** - Uses parsed layout to generate blkdevparts
   - Creates `blkdevparts=mmcblk0:32K(env),512K@32K(idblock),...`
   - Adjusts device name based on `ROCKCHIP_BOOT_MEDIUM`

3. **rockchip-disk.bbclass** - Uses parsed offsets to write disk image
   - Reads `ROCKCHIP_PART_*_OFFSET` variables
   - Writes each component at correct location

## SDK Compatibility

The partition string format matches the SDK's `RK_PARTITION_CMD_IN_ENV` variable from BoardConfig files.

### SDK BoardConfig Example

```bash
RK_PARTITION_CMD_IN_ENV="32K(env),512K@32K(idblock),256K(uboot),32M(boot),6G(rootfs)"
```

### Yocto Equivalent

```bitbake
ROCKCHIP_PARTITION_LAYOUT = "32K(env),512K@32K(idblock),256K(uboot),32M(boot),6G(rootfs)"
```

## Variables Reference

### Input Variables

- `ROCKCHIP_PARTITION_LAYOUT` - Partition layout string
- `ROCKCHIP_BOOT_MEDIUM` - Boot device type (emmc, sd_card, spi_nand, spi_nor)

### Generated Variables  

- `ROCKCHIP_BLKDEVPARTS` - Full blkdevparts string for U-Boot
- `ROCKCHIP_PART_<NAME>_SIZE` - Partition size in bytes
- `ROCKCHIP_PART_<NAME>_OFFSET` - Partition offset in bytes
- `ROCKCHIP_PART_<NAME>_SIZE_STR` - Original size string (e.g., "32M")

### Example Usage in Recipes

```bitbake
inherit rockchip-partition

do_compile() {
    # Access parsed partition info
    echo "Boot partition offset: ${ROCKCHIP_PART_BOOT_OFFSET}"
    echo "Boot partition size: ${ROCKCHIP_PART_BOOT_SIZE}"
    echo "Rootfs offset: ${ROCKCHIP_PART_ROOTFS_OFFSET}"
}
```
