FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

do_install:append() {
    # Remove the default "1" console entry that's failing
    sed -i '/^1:.*getty.*$/d' ${D}${sysconfdir}/inittab
    
    # Add serial console on ttyFIQ0 (FIQ debugger)
    echo "" >> ${D}${sysconfdir}/inittab
    echo "# Serial console on ttyFIQ0" >> ${D}${sysconfdir}/inittab  
    echo "S0:12345:respawn:/sbin/getty 115200 ttyFIQ0" >> ${D}${sysconfdir}/inittab
    
    # Add USB gadget serial console if usbgadget feature is enabled
    if ${@bb.utils.contains('MACHINE_FEATURES', 'usbgadget', 'true', 'false', d)}; then
        echo "" >> ${D}${sysconfdir}/inittab
        echo "# USB gadget serial console" >> ${D}${sysconfdir}/inittab
        echo "GS0:12345:respawn:/sbin/getty -L ttyGS0 115200 vt100" >> ${D}${sysconfdir}/inittab
    fi
}
