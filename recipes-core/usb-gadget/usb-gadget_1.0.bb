SUMMARY = "USB Gadget configuration for Luckfox Pico"
DESCRIPTION = "Configures USB OTG as ACM (serial console) and RNDIS (Ethernet over USB)"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI = "file://S50usbgadget \
           file://usb-console.inittab \
"

inherit update-rc.d

INITSCRIPT_NAME = "S50usbgadget"
INITSCRIPT_PARAMS = "start 50 S . stop 50 0 6 ."

do_install() {
    install -d ${D}${sysconfdir}/init.d
    install -m 0755 ${UNPACKDIR}/S50usbgadget ${D}${sysconfdir}/init.d/S50usbgadget
}

FILES:${PN} = "${sysconfdir}/init.d/S50usbgadget"

# Note: USB gadget functionality requires CONFIG_USB_CONFIGFS and CONFIG_USB_LIBCOMPOSITE
# to be enabled in the kernel config. The libcomposite module is built into the kernel
# or loaded automatically, not a separate package.

RDEPENDS:${PN} = "iproute2"

PACKAGE_ARCH = "${MACHINE_ARCH}"
