SUMMARY = "Userdata partition initialization"
DESCRIPTION = "First-boot script to format and resize userdata partition to maximum available size"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://userdata-init"

RDEPENDS:${PN} = "e2fsprogs e2fsprogs-resize2fs e2fsprogs-e2fsck e2fsprogs-mke2fs util-linux-blkid util-linux-mountpoint"

inherit update-rc.d

INITSCRIPT_NAME = "userdata-init"
INITSCRIPT_PARAMS = "start 05 S ."

# No source to unpack, just files
do_configure[noexec] = "1"
do_compile[noexec] = "1"

do_install() {
    install -d ${D}${sysconfdir}/init.d
    install -m 0755 ${UNPACKDIR}/userdata-init ${D}${sysconfdir}/init.d/userdata-init
    
    # Create mount point for userdata
    install -d ${D}/data
}

FILES:${PN} += "/data"
