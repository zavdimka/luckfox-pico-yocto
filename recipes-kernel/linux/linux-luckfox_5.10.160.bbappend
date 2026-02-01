# Create FIT image for Rockchip boot_fit command

DEPENDS += "u-boot-tools-native"

do_deploy:append() {
    # Create FIT image with kernel, DTB, and resource
    cd ${B}
    
    # Copy boot.its template from kernel source
    ITS_TEMPLATE="${S}/boot.its"
    ITS_FILE="${B}/boot.its"
    
    if [ ! -f "${ITS_TEMPLATE}" ]; then
        bbfatal "boot.its template not found at ${ITS_TEMPLATE}"
    fi
    
    # Create output directory for FIT components
    mkdir -p ${B}/fit-out
    
    # Find the DTB file that was deployed (use KERNEL_DEVICETREE from machine config)
    DTB_NAME="${KERNEL_DEVICETREE}"
    DTB_SOURCE="${DEPLOYDIR}/${DTB_NAME}"
    
    if [ ! -f "${DTB_SOURCE}" ]; then
        bbfatal "DTB not found at ${DTB_SOURCE}"
    fi
    
    # Copy kernel image (uncompressed for arm)
    if [ -f "${B}/arch/${ARCH}/boot/Image" ]; then
        cp ${B}/arch/${ARCH}/boot/Image ${B}/fit-out/kernel
    else
        bbfatal "Kernel Image not found at ${B}/arch/${ARCH}/boot/Image"
    fi
    
    # Copy device tree
    cp ${DTB_SOURCE} ${B}/fit-out/fdt
    
    # Build resource_tool if not already built
    RESOURCE_TOOL="${B}/scripts/resource_tool"
    if [ ! -x "${RESOURCE_TOOL}" ]; then
        bbnote "Building resource_tool..."
        cd ${B}/scripts
        ${BUILD_CC} -o resource_tool ${S}/scripts/resource_tool.c
        cd ${B}
    fi
    
    # Create resource.img with DTB
    if [ -x "${RESOURCE_TOOL}" ]; then
        ${RESOURCE_TOOL} ${DTB_SOURCE} ${B}/resource.img >/dev/null 2>&1
        if [ -f ${B}/resource.img ]; then
            cp ${B}/resource.img ${B}/fit-out/resource
            bbnote "resource.img created successfully"
        else
            bbwarn "resource_tool failed to create resource.img, using empty resource"
            touch ${B}/fit-out/resource
        fi
    else
        bbwarn "resource_tool not available, using empty resource"
        touch ${B}/fit-out/resource
    fi
    
    # Prepare boot.its with correct arch and compression settings
    cp "${ITS_TEMPLATE}" "${B}/fit-out/boot.its"
    sed -i -e 's/arch = ""/arch = "arm"/g' \
           -e 's/compression = ""/compression = "none"/g' \
           "${B}/fit-out/boot.its"
    
    # Build FIT image (run from fit-out directory where all files are)
    cd ${B}/fit-out
    mkimage -E -p 0x800 -f boot.its boot.img
    
    # Deploy FIT image
    install -m 0644 ${B}/fit-out/boot.img ${DEPLOYDIR}/boot.img
    
    bbnote "FIT image boot.img created and deployed"
}
