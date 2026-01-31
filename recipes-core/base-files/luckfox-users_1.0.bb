SUMMARY = "Luckfox Pico user accounts"
DESCRIPTION = "Creates default user account for Luckfox Pico"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit useradd

# Create 'luckfox' user with password 'luckfox'
# Password hash generated with: openssl passwd -6 luckfox
USERADD_PACKAGES = "${PN}"
USERADD_PARAM:${PN} = "-u 1000 -d /home/luckfox -s /bin/sh -G video,audio,input,dialout -p '\$6\$Ei0Zk3pc08WENGGg\$k/7oW7l5XaBLyOXS94JJZNUJDNxpO6yrwVM2MQfmOHgkgx/wKbr.UXCxD8NTL.5pwqoPrLlJLrLxam95VoXO50' luckfox"

# Create home directory
do_install() {
    install -d ${D}/home/luckfox
    chown 1000:1000 ${D}/home/luckfox
}

FILES:${PN} = "/home/luckfox"
