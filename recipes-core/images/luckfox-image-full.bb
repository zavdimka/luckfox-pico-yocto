# Minimal image for Luckfox Pico RV1106
require recipes-core/images/core-image-minimal.bb

IMAGE_FEATURES += "ssh-server-dropbear"

# Add user account
IMAGE_INSTALL:append = " luckfox-users"

# Add kernel module utilities and init scripts
IMAGE_INSTALL:append = " kernel-modules kmod"

# Add USB Gadget support (ACM serial console + RNDIS ethernet)
# Add USB gadget configuration if machine supports it
IMAGE_INSTALL:append = "${@bb.utils.contains('MACHINE_FEATURES', 'usbgadget', ' usb-gadget', '', d)}"

# Add WiFi driver modules
IMAGE_INSTALL:append = " kernel-module-aic8800dc"

# Add WiFi utilities
IMAGE_INSTALL:append = " iw wpa-supplicant avftp"

# Add Python3 minimal (core interpreter + essential modules)
IMAGE_INSTALL:append = " python3-core python3-modules"

# A/B Update: Add libubootenv and boot success marker
IMAGE_INSTALL:append = "${@' libubootenv-bin ab-boot-success' if d.getVar('RK_ENABLE_AB_UPDATE') == '1' else ''}"

# Userdata partition initialization (format and resize on first boot)
IMAGE_INSTALL:append = " userdata-init"

# Add U-Boot environment for bootloader
DEPENDS += "u-boot-luckfox u-boot-env"

# Use custom Rockchip disk image format instead of WIC
inherit rockchip-disk

# Select filesystem type based on boot medium
# eMMC/SD: ext4 filesystem
# SPI NAND: UBIFS + UBI volumes
IMAGE_FSTYPES = "${@'ext4 rockchip-disk' if d.getVar('RK_BOOT_MEDIUM') in ['emmc', 'sd_card'] else 'ubifs ubi rockchip-disk'}"

# Proprietary multimedia stack is optional; leave out by default
# IMAGE_INSTALL:append = " rockchip-luckfox-blobs"

OLDEST_KERNEL = "5.10"
ROOT_HOME = "/root"