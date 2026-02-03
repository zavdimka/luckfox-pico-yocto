# A/B Update System - Implementation Summary

## Overview
Dual boot A/B update system with automatic rollback on boot failure. The system maintains two complete boot environments (boot_a + rootfs_a, boot_b + rootfs_b) and automatically switches to the backup slot if the active slot fails to boot 3 times.

## Partition Layout (A/B Mode Enabled)

| Partition  | Offset    | Size      | Device Node    | Purpose                    |
|------------|-----------|-----------|----------------|----------------------------|
| env        | 0         | 32KB      | N/A            | U-Boot environment         |
| idblock    | 32KB      | 256KB     | N/A            | Rockchip bootloader ID     |
| uboot      | 288KB     | 256KB     | N/A            | U-Boot bootloader          |
| boot_a     | 544KB     | 64MB      | /dev/mmcblk0p4 | Slot A kernel FIT image    |
| boot_b     | ~64.5MB   | 64MB      | /dev/mmcblk0p5 | Slot B kernel FIT image    |
| rootfs_a   | ~128.5MB  | 3GB       | /dev/mmcblk0p6 | Slot A root filesystem     |
| rootfs_b   | ~3.2GB    | 3GB       | /dev/mmcblk0p7 | Slot B root filesystem     |
| userdata   | ~6.2GB    | Remaining | /dev/mmcblk0p8 | Persistent user data       |

## Configuration

### Enable/Disable A/B Updates
Edit `conf/machine/luckfox-pico.conf`:
```bitbake
RK_ENABLE_AB_UPDATE = "1"  # Enable A/B updates (default)
RK_ENABLE_AB_UPDATE = "0"  # Disable (single boot partition)
```

### Build the Image
```bash
cd /home/dimka/luckfox-pico/yocto-walnascar/build-luckfox
bitbake luckfox-image-minimal
```

The build system automatically:
- Creates A/B partition layout (boot_a, boot_b, rootfs_a, rootfs_b)
- Duplicates boot.img to both boot_a and boot_b partitions
- Duplicates rootfs to both rootfs_a and rootfs_b partitions
- Configures U-Boot with A/B boot logic

## Boot Flow

### Initial Boot (Slot A)
1. U-Boot reads `active_slot=a` and `boot_counter=0`
2. Increments `boot_counter` to 1
3. Sets `part_boot=boot_a` and `root=/dev/mmcblk0p6`
4. Loads kernel from boot_a partition
5. Boots into rootfs_a

### Successful Boot
- Init script `/etc/init.d/ab-boot-success` runs
- Detects successful boot and resets `boot_counter=0`
- System continues running on Slot A

### Boot Failure (3 consecutive failures)
1. U-Boot increments `boot_counter` on each failed boot attempt
2. After 3 failures (`boot_counter > boot_limit`):
   - Switches `active_slot` from `a` to `b`
   - Resets `boot_counter=0`
   - Saves environment to flash
3. Next boot uses Slot B (boot_b + rootfs_b)

## U-Boot Environment Variables

| Variable      | Default | Description                                    |
|---------------|---------|------------------------------------------------|
| active_slot   | a       | Currently active slot (a or b)                 |
| boot_counter  | 0       | Boot attempt counter for current slot          |
| boot_limit    | 3       | Max boot attempts before switching slots       |
| part_boot     | dynamic | Boot partition name (boot_a or boot_b)         |

## Manual Slot Management

### Check Current Slot
```bash
fw_printenv active_slot
fw_printenv boot_counter
```

### Switch to Slot B
```bash
fw_setenv active_slot b
fw_setenv boot_counter 0
reboot
```

### Switch Back to Slot A
```bash
fw_setenv active_slot a
fw_setenv boot_counter 0
reboot
```

### Reset Boot Counter (Mark Boot as Successful)
```bash
fw_setenv boot_counter 0
```

## OTA Update Workflow

### Step 1: Determine Inactive Slot
```bash
ACTIVE=$(fw_printenv -n active_slot)
if [ "$ACTIVE" = "a" ]; then
    INACTIVE_BOOT="/dev/mmcblk0p5"    # boot_b
    INACTIVE_ROOTFS="/dev/mmcblk0p7"  # rootfs_b
else
    INACTIVE_BOOT="/dev/mmcblk0p4"    # boot_a
    INACTIVE_ROOTFS="/dev/mmcblk0p6"  # rootfs_a
fi
```

### Step 2: Write New Image to Inactive Slot
```bash
# Write new kernel FIT image
dd if=boot.img of=$INACTIVE_BOOT bs=1M

# Write new rootfs
dd if=rootfs.ext4 of=$INACTIVE_ROOTFS bs=1M
```

### Step 3: Switch to New Slot
```bash
if [ "$ACTIVE" = "a" ]; then
    fw_setenv active_slot b
else
    fw_setenv active_slot a
fi
fw_setenv boot_counter 0
```

### Step 4: Reboot
```bash
reboot
```

### Step 5: Automatic Validation
- If new slot boots successfully: `ab-boot-success` resets `boot_counter=0`
- If new slot fails 3 times: U-Boot automatically rolls back to old slot

## Implementation Files

### Modified Files
- **conf/machine/luckfox-pico.conf** - A/B partition layout and configuration
- **classes/rockchip-disk.bbclass** - Partition duplication logic
- **recipes-bsp/u-boot/u-boot-env_1.0.bb** - A/B boot script

### New Files
- **recipes-core/ab-boot-success/ab-boot-success_1.0.bb** - Boot success marker recipe
- **recipes-core/ab-boot-success/files/ab-boot-success** - Init script
- **recipes-core/images/luckfox-image-minimal.bb** - Added libubootenv-bin and ab-boot-success

## Testing A/B Rollback

### Test Automatic Rollback
```bash
# Corrupt active rootfs to trigger boot failure
fw_setenv active_slot a
fw_setenv boot_counter 0
dd if=/dev/zero of=/dev/mmcblk0p6 bs=1M count=1
reboot
```

Expected behavior:
- Boot attempt 1: Fails (boot_counter=1)
- Boot attempt 2: Fails (boot_counter=2)
- Boot attempt 3: Fails (boot_counter=3)
- Boot attempt 4: Switches to Slot B (active_slot=b, boot_counter=0)
- System boots successfully from Slot B

### Verify Slot Switch
After automatic rollback:
```bash
fw_printenv active_slot  # Should show 'b'
fw_printenv boot_counter # Should show '0'
mount | grep "on / type" # Should show /dev/mmcblk0p7
```

## Userdata Partition

The userdata partition (/dev/mmcblk0p8) is shared between both slots and persists across updates. Mount it at `/data` or `/home` for user files that should survive updates.

Add to `/etc/fstab`:
```
/dev/mmcblk0p8  /data  ext4  defaults  0  2
```

## Disabling A/B Updates

To revert to single boot partition mode:

1. Edit `conf/machine/luckfox-pico.conf`:
   ```bitbake
   RK_ENABLE_AB_UPDATE = "0"
   ```

2. Rebuild:
   ```bash
   bitbake -c cleansstate luckfox-image-minimal
   bitbake luckfox-image-minimal
   ```

Result:
- Single partition layout: boot (32MB), rootfs (fills remaining)
- No A/B logic in U-Boot environment
- Standard boot flow without rollback

## Recommended Enhancements

1. **RAUC Integration** - Professional OTA update framework with bundle verification
2. **Atomic Updates** - Write entire partition image as single transaction
3. **Signature Verification** - Verify update package signatures before applying
4. **Network Update** - Automatic download and installation of updates
5. **Update Status API** - Expose slot status via D-Bus or REST API
