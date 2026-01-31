# Override for Luckfox kernel with external toolchain
# The kernel build doesn't support standard 'prepare' or 'scripts' targets
# Scripts are already built during kernel compilation

do_configure() {
    # Scripts already exist in ${STAGING_KERNEL_BUILDDIR}/scripts
    # Verify they exist
    if [ ! -d "${STAGING_KERNEL_BUILDDIR}/scripts" ]; then
        bbfatal "Kernel scripts not found in ${STAGING_KERNEL_BUILDDIR}/scripts"
    fi
    
    # Nothing to do - scripts are already built
    bbnote "Using pre-built kernel scripts from ${STAGING_KERNEL_BUILDDIR}/scripts"
}

do_compile() {
    # Scripts are already compiled, nothing to do
    :
}
