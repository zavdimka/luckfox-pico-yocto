# Class to parse Rockchip partition layout (SDK-compatible format)

# Boot medium type (emmc, sd_card, spi_nand, spi_nor, slc_nand)
ROCKCHIP_BOOT_MEDIUM ??= "emmc"

def parse_rockchip_partitions(d):
    """Parse partition layout string into structured data"""
    import re
    
    def parse_size(size_str):
        """Convert size string (like 32K, 512M, 6G) to bytes"""
        match = re.match(r'^(\d+)([KMGTP]?)$', size_str.strip().upper())
        if not match:
            bb.fatal(f"Invalid size format: {size_str}")
        
        value = int(match.group(1))
        unit = match.group(2) if match.group(2) else ''
        
        multipliers = {
            '': 1,
            'K': 1024,
            'M': 1024 * 1024,
            'G': 1024 * 1024 * 1024,
            'T': 1024 * 1024 * 1024 * 1024,
            'P': 1024 * 1024 * 1024 * 1024 * 1024,
        }
        
        return value * multipliers[unit]
    
    layout = d.getVar('RK_PARTITION_LAYOUT')
    if not layout:
        bb.fatal("RK_PARTITION_LAYOUT is not defined. Please set RK_PARTITION_LAYOUT in your machine configuration.")
    
    partitions = []
    offset = 0
    
    for part_str in layout.split(','):
        part_str = part_str.strip()
        
        # Parse: size@offset(name:fstype) or size(name:fstype) or size(name)
        # fstype is optional after the name, separated by colon
        match = re.match(r'^([^@(]+)(?:@([^(]+))?\(([^):]+)(?::([^)]+))?\)', part_str)
        if not match:
            bb.fatal(f"Invalid partition format: {part_str}")
        
        size_str = match.group(1).strip()
        offset_str = match.group(2).strip() if match.group(2) else None
        name = match.group(3).strip()
        fstype = match.group(4).strip() if match.group(4) else None
        
        # Parse size (supports K, M, G, T or -)
        if size_str == '-':
            size_bytes = -1  # Variable size (fill remaining)
        else:
            size_bytes = parse_size(size_str)
        
        # Parse offset if specified
        if offset_str:
            offset = parse_size(offset_str)
        
        part_info = {
            'name': name,
            'size': size_bytes,
            'offset': offset,
            'size_str': size_str,
            'fstype': fstype,
        }
        
        partitions.append(part_info)
        
        # Update offset for next partition (if size is known)
        if size_bytes > 0:
            offset += size_bytes
    
    # Store parsed partitions in datastore
    d.setVar('RK_PARTITIONS_PARSED', str(partitions))
    
    # Export individual partition info for easy access
    for part in partitions:
        var_prefix = f"RK_PART_{part['name'].upper().replace('-', '_')}"
        d.setVar(f"{var_prefix}_SIZE", str(part['size']))
        d.setVar(f"{var_prefix}_OFFSET", str(part['offset']))
        d.setVar(f"{var_prefix}_SIZE_STR", part['size_str'])
        if part['fstype']:
            d.setVar(f"{var_prefix}_FSTYPE", part['fstype'])

# Parse partitions early (before recipes need the data)
python() {
    # Verify required variables are set
    layout = d.getVar('RK_PARTITION_LAYOUT')
    if not layout:
        bb.fatal("RK_PARTITION_LAYOUT is not defined. Please set RK_PARTITION_LAYOUT in your machine configuration.")
    
    medium = d.getVar('RK_BOOT_MEDIUM')
    if not medium:
        bb.fatal("RK_BOOT_MEDIUM is not defined. Please set RK_BOOT_MEDIUM in your machine configuration.")
    
    parse_rockchip_partitions(d)
    
    # Generate blkdevparts/mtdparts string for U-Boot
    layout = d.getVar('RK_PARTITION_LAYOUT')
    medium = d.getVar('RK_BOOT_MEDIUM')
    
    if medium == 'emmc':
        device = 'mmcblk0'
        blkdevparts = f"blkdevparts={device}:{layout}"
        d.setVar('RK_DEVICE_PREFIX', 'mmcblk0p')
        d.setVar('RK_PART_NUM_START', '1')
    elif medium == 'sd_card':
        device = 'mmcblk1'
        blkdevparts = f"blkdevparts={device}:{layout}"
        d.setVar('RK_DEVICE_PREFIX', 'mmcblk1p')
        d.setVar('RK_PART_NUM_START', '1')
    elif medium == 'spi_nand':
        device = 'spi-nand0'
        blkdevparts = f"mtdparts={device}:{layout}"
        d.setVar('RK_DEVICE_PREFIX', 'mtd')
        d.setVar('RK_PART_NUM_START', '0')
    elif medium == 'spi_nor':
        device = 'sfc_nor'
        blkdevparts = f"mtdparts={device}:{layout}"
        d.setVar('RK_DEVICE_PREFIX', 'mtdblock')
        d.setVar('RK_PART_NUM_START', '0')
    elif medium == 'slc_nand':
        device = 'rk-nand'
        blkdevparts = f"mtdparts={device}:{layout}"
        d.setVar('RK_DEVICE_PREFIX', 'mtd')
        d.setVar('RK_PART_NUM_START', '0')
    else:
        device = medium
        blkdevparts = f"{device}:{layout}"
        d.setVar('RK_DEVICE_PREFIX', device)
        d.setVar('RK_PART_NUM_START', '0')
    
    d.setVar('RK_BLKDEVPARTS', blkdevparts)
    d.setVar('RK_PARTITION_ARGS', blkdevparts)
}
