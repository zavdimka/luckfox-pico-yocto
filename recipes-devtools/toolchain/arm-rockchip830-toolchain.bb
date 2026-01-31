SUMMARY = "Vendor cross toolchain arm-rockchip830-linux-uclibcgnueabihf"
DESCRIPTION = "Fetches the Luckfox vendor toolchain from GitHub and stages it for external-toolchain builds."
LICENSE = "CLOSED"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/Proprietary;md5=8d3a0ba0fbe7e2c93d7f1cc2e1d9175f"

SRC_URI = "git://github.com/LuckfoxTECH/luckfox-pico.git;protocol=https;branch=main;subpath=tools/linux/toolchain/arm-rockchip830-linux-uclibcgnueabihf"
SRCREV = "${AUTOREV}"

S = "${WORKDIR}/git/tools/linux/toolchain/arm-rockchip830-linux-uclibcgnueabihf"

# No packages produced; just deploy the toolchain for external use
PACKAGES = ""
INHIBIT_DEFAULT_DEPS = "1"

inherit nopackages

python do_install() {
    import shutil, os
    dest = d.getVar('D') + '/opt/arm-rockchip830-linux-uclibcgnueabihf'
    os.makedirs(dest, exist_ok=True)
    shutil.copytree(d.getVar('S'), dest, dirs_exist_ok=True)
}

do_deploy() {
    install -d ${DEPLOYDIR}/external-toolchain
    cp -a ${D}/opt/arm-rockchip830-linux-uclibcgnueabihf ${DEPLOYDIR}/external-toolchain/
}

addtask deploy after do_install
