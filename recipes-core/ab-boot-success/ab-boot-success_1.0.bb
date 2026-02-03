SUMMARY = "A/B Update boot success marker"
DESCRIPTION = "Init script to reset U-Boot boot counter on successful boot for A/B updates"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://ab-boot-success"

RDEPENDS:${PN} = "libubootenv-bin"

inherit update-rc.d

INITSCRIPT_NAME = "ab-boot-success"
INITSCRIPT_PARAMS = "start 99 2 3 4 5 ."

# No source to unpack, just files
do_configure[noexec] = "1"
do_compile[noexec] = "1"

do_install() {
    install -d ${D}${sysconfdir}/init.d
    install -m 0755 ${UNPACKDIR}/ab-boot-success ${D}${sysconfdir}/init.d/ab-boot-success
}
