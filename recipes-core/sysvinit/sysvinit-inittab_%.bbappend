FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

do_install:append() {
    # Remove the default "1" console entry that's failing
    sed -i '/^1:.*getty.*$/d' ${D}${sysconfdir}/inittab
    
    # Add serial console on ttyFIQ0 (FIQ debugger)
    echo "" >> ${D}${sysconfdir}/inittab
    echo "# Serial console on ttyFIQ0" >> ${D}${sysconfdir}/inittab  
    echo "S0:12345:respawn:/sbin/getty 115200 ttyFIQ0" >> ${D}${sysconfdir}/inittab
}
