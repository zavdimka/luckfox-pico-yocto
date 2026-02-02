# Minimal image for Luckfox Pico RV1106
require recipes-core/images/core-image-minimal.bb

IMAGE_FEATURES += "ssh-server-dropbear"

# Add user account
IMAGE_INSTALL:append = " luckfox-users"

# Add kernel module utilities and init scripts
IMAGE_INSTALL:append = " kernel-modules kmod"

# Add USB Gadget support (ACM serial console + RNDIS ethernet)
IMAGE_INSTALL:append = " usb-gadget"

# Add WiFi driver modules
IMAGE_INSTALL:append = " kernel-module-aic8800dc"

# Add U-Boot environment for bootloader
DEPENDS += "u-boot-luckfox u-boot-env"

# Use custom Rockchip disk image format instead of WIC
inherit rockchip-disk
# ext4 for eMMC/SD, ubifs+ubi for SPI NAND (ubi depends on ubifs)
IMAGE_FSTYPES = "ext4 ubifs ubi rockchip-disk"

# Proprietary multimedia stack is optional; leave out by default
# IMAGE_INSTALL:append = " rockchip-luckfox-blobs"

OLDEST_KERNEL = "5.10"
ROOT_HOME = "/root"