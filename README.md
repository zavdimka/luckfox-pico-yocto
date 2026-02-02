# Luckfox Pico Yocto Project

[![Yocto Project](https://img.shields.io/badge/Yocto-5.1%20Scarthgap-blue)](https://www.yoctoproject.org/)
[![License](https://img.shields.io/badge/license-Mixed-green)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Rockchip%20RV1106-orange)](https://www.rock-chips.com/)

Modern Yocto/OpenEmbedded build system for **Luckfox Pico** boards based on Rockchip RV1106 SoC. This project provides a clean, maintainable alternative to the vendor SDK with full integration into the Yocto ecosystem.

## 🎯 Features

- ✅ **Yocto Scarthgap (5.1)** - Latest stable Yocto release
- ✅ **Multiple Boot Media** - eMMC, SD card, SPI NAND (tested ✓) with SDK-compatible partition layouts
- ✅ **FIT Boot Images** - Flattened Image Tree format with kernel, DTB, and ramdisk
- ✅ **U-Boot Integration** - Custom bootloader with environment configuration
- ✅ **WiFi Drivers** - AIC8800DC wireless support
- ✅ **Complete Disk Images** - Ready-to-flash `.img` files for all boot media
- ✅ **UBI/UBIFS Support** - Full UBI/UBIFS implementation for SPI NAND flash
- ✅ **SDK Compatibility** - Partition layout compatible with Luckfox SDK format
- ✅ **USB Gadget Support** - Serial console (ttyGS0) and Ethernet over USB (RNDIS)

## 📋 Prerequisites

### System Requirements

- **OS**: Ubuntu 22.04 LTS or Debian 12 (other distros may work)
- **Disk Space**: At least 100GB free space
- **RAM**: 8GB minimum, 16GB+ recommended
- **CPU**: Multi-core processor recommended for faster builds

### Supported Host Systems

- Ubuntu 22.04 LTS (Recommended)
- Debian 12 (Bookworm)
- Fedora 38+
- openSUSE Leap 15.4+

## 🚀 Quick Start

### 1. Install Git

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y git

# Fedora
sudo dnf install -y git

# Verify installation
git --version
```

### 2. Install Yocto Dependencies

#### Ubuntu/Debian

```bash
sudo apt update
sudo apt install -y gawk wget git diffstat unzip texinfo gcc build-essential \
    chrpath socat cpio python3 python3-pip python3-pexpect xz-utils \
    debianutils iputils-ping python3-git python3-jinja2 python3-subunit \
    mesa-common-dev zstd liblz4-tool file locales libacl1 \
    gcc-multilib g++-multilib

# Generate required locale
sudo locale-gen en_US.UTF-8
```

#### Fedora

```bash
sudo dnf install -y gawk make wget tar bzip2 gzip python3 unzip perl patch \
    diffutils diffstat git cpp gcc gcc-c++ glibc-devel texinfo chrpath \
    ccache perl-Data-Dumper perl-Text-ParseWords perl-Thread-Queue \
    python3-GitPython python3-jinja2 python3-pexpect xz which SDL-devel \
    zstd lz4 file hostname rpcgen
```

### 3. Clone the Repository

```bash
# Clone with submodules (includes Yocto Poky and meta-openembedded)
git clone --recursive https://github.com/zavdimka/luckfox-pico-yocto.git
cd luckfox-pico-yocto

# If you already cloned without --recursive, initialize submodules:
git submodule update --init --recursive
```

### 4. Initialize Build Environment

```bash
# Source the Yocto build environment
source ../yocto-walnascar/poky/oe-init-build-env ../yocto-walnascar/build-luckfox

# This will create the build directory and configuration files
# You should now be in the build directory
```

### 5. Build Your First Image

#### Option A: Minimal Image (Recommended for first build)

```bash
# Build minimal bootable image (~30-60 minutes on modern hardware)
bitbake luckfox-image-minimal
```

#### Option B: Full-Featured Image

```bash
# Build image with development tools and utilities
bitbake luckfox-image-full
```

### 6. Flash the Image

After successful build, images will be in:
```
yocto-walnascar/build-luckfox/tmp/deploy/images/luckfox-pico/
```

#### Flash to SD Card (Linux)

```bash
# Find your SD card device (e.g., /dev/sdX - BE CAREFUL!)
lsblk

# Flash the image (replace /dev/sdX with your SD card device)
sudo dd if=luckfox-image-minimal-luckfox-pico.img of=/dev/sdX bs=4M status=progress
sudo sync
```

#### Flash to eMMC (using Rockchip tools)

```bash
# Use Rockchip upgrade_tool or rkdeveloptool
sudo upgrade_tool wl 0 luckfox-image-minimal-luckfox-pico.img
```

## 🏗️ Project Structure

```
luckfox-pico-yocto/
├── conf/
│   ├── layer.conf                     # Layer configuration
│   ├── bblayers.conf                  # Build layers configuration
│   ├── local.conf                     # Local build settings
│   ├── distro/                        # Distribution configs
│   └── machine/
│       ├── luckfox-pico.conf          # eMMC machine config
│       ├── luckfox-pico-sd.conf       # SD card machine config
│       └── luckfox-pico-spi-nand.conf # SPI NAND machine config
├── classes/
│   ├── luckfox-ext-toolchain.bbclass  # External toolchain support
│   ├── rockchip-disk.bbclass          # Disk image creation
│   └── rockchip-partition.bbclass     # Partition layout parser
├── recipes-kernel/
│   ├── linux/                         # Linux kernel 5.10.160
│   │   ├── linux-luckfox_5.10.160.bb  # Kernel recipe
│   │   ├── linux-luckfox_5.10.160.bbappend  # FIT image support
│   │   └── files/                     # Kernel configs & DTS files
│   ├── aic8800dc/                     # AIC8800DC WiFi driver
│   └── make-mod-scripts/              # Kernel module build support
├── recipes-bsp/
│   └── u-boot/
│       ├── u-boot-luckfox/            # U-Boot 2017.09 recipe
│       └── u-boot-env/                # Environment configuration
├── recipes-core/
│   ├── images/
│   │   └── luckfox-image-minimal.bb   # Minimal bootable image
│   ├── base-files/                    # Base system files
│   ├── sysvinit/                      # Init system configuration
│   │   └── sysvinit-inittab_%.bbappend  # Serial console support (ttyFIQ0, ttyGS0)
│   └── usb-gadget/                    # USB gadget support
│       └── usb-gadget_1.0.bb          # ACM serial + RNDIS ethernet
├── recipes-devtools/
│   └── toolchain/                     # External toolchain setup
├── recipes-extended/
│   └── xz/                            # XZ compression utilities
├── README.md
├── README-PARTITIONS.md               # Partition layout documentation
└── .gitignore
```
└── README.md
```

## 🎛️ Configuration

### Build for Different Boot Media

#### eMMC (default)

```bash
# Edit conf/local.conf or use:
MACHINE=luckfox-pico bitbake luckfox-image-minimal
```

#### SD Card ✅ Tested & Working

```bash
# Build for SD card (uses mmcblk1 instead of mmcblk0)
MACHINE=luckfox-pico-sd bitbake luckfox-image-minimal
```

#### SPI NAND ✅ Tested & Working

```bash
# Build for SPI NAND with UBI/UBIFS support
MACHINE=luckfox-pico-spi-nand bitbake luckfox-image-minimal
```

**Important**: Before flashing to SPI NAND for the first time, or when upgrading from old images, **erase the flash** in U-Boot console to prevent UBI image sequence conflicts:

```
# In U-Boot console:
nand erase.part rootfs
```

Then flash the image using `rkdeveloptool` or `upgrade_tool` as usual.

### Customize Partition Layout

Edit your machine config or `local.conf`:

```bash
# Example: Larger boot partition
ROCKCHIP_PARTITION_LAYOUT = "32K(env),512K@32K(idblock),256K(uboot),32M(boot),-(rootfs)"

# Example: With OEM and userdata partitions
ROCKCHIP_PARTITION_LAYOUT = "32K(env),512K@32K(idblock),256K(uboot),32M(boot),-(rootfs)"
```

See [README-PARTITIONS.md](README-PARTITIONS.md) for details.

### Add Packages to Image

Edit `conf/local.conf`:

```bash
# Add packages to all images
IMAGE_INSTALL:append = " python3 htop nano"

# Or edit image recipe directly
```

### Enable WiFi Drivers

```bash
# Add to conf/local.conf
IMAGE_INSTALL:append = " kernel-module-aic8800dc"
# or
IMAGE_INSTALL:append = " kernel-module-rtl8188ftv"
```

## 🔧 Advanced Usage

### Clean Builds

```bash
# Clean specific recipe
bitbake -c cleanall linux-luckfox

# Clean specific package
bitbake -c cleansstate u-boot-luckfox

# Clean everything (fresh start)
rm -rf tmp sstate-cache
```

### Interactive Development

```bash
# Open development shell for a recipe
bitbake -c devshell linux-luckfox

# This opens a shell with all build environment variables set
```

### Building SDK

```bash
# Build SDK for application development
bitbake -c populate_sdk luckfox-image-minimal

# SDK will be in tmp/deploy/sdk/
```

### Incremental Builds

After modifying recipes, rebuild efficiently:

```bash
# Rebuild only changed components
bitbake luckfox-image-minimal

# Force rebuild of specific component
bitbake -c compile -f linux-luckfox
bitbake luckfox-image-minimal
```

## 📦 Available Images

### luckfox-image-minimal

Minimal bootable system with:
- Linux kernel 5.10.160
- BusyBox userland
- Basic networking
- Serial console
- ~50MB rootfs

### luckfox-image-full

Full-featured system with:
- Development tools (gcc, make, cmake)
- Python 3
- Network utilities
- System administration tools
- ~200MB rootfs

## 🐛 Troubleshooting

### Build Fails with "No space left on device"

Ensure you have at least 100GB free space. Clean old builds:

```bash
rm -rf tmp/work/*
```

### Git Submodules Not Found

```bash
git submodule update --init --recursive
```

### Python locale errors

```bash
sudo locale-gen en_US.UTF-8
export LC_ALL=en_US.UTF-8
```

### Fetch failures

```bash
# Clean downloads and retry
rm -rf downloads
bitbake <recipe-name>
```

### Hash mismatch errors

```bash
# Clean sstate and rebuild
bitbake -c cleansstate <recipe-name>
bitbake <recipe-name>
```

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📚 Documentation

- [Partition Layout System](README-PARTITIONS.md) - SDK-compatible partition configuration
- [Yocto Project Documentation](https://docs.yoctoproject.org/)
- [Luckfox Wiki](https://wiki.luckfox.com/)
- [Rockchip RV1106 Documentation](https://www.rock-chips.com/)

## 📝 License

This project is licensed under mixed licenses. See individual recipe files for specific license information:

- Layer configuration: MIT
- Recipes: Various (GPL-2.0, MIT, Apache-2.0)
- Linux kernel: GPL-2.0
- U-Boot: GPL-2.0+

## 🙏 Acknowledgments

- **Luckfox Team** - Original SDK and hardware
- **Yocto Project** - Build system
- **Rockchip** - SoC vendor
- **OpenEmbedded Community** - Metadata layers

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/zavdimka/luckfox-pico-yocto/issues)
- **Discussions**: [GitHub Discussions](https://github.com/zavdimka/luckfox-pico-yocto/discussions)
- **Luckfox Forum**: [Official Forum](https://www.luckfox.com/forum)

## 🗺️ Roadmap

- [x] Basic Yocto layer structure
- [x] U-Boot integration
- [x] Linux kernel 5.10.160
- [x] WiFi driver support (AIC8800DC)
- [x] FIT boot image generation
- [x] Complete disk image creation
- [x] SDK-compatible partition layouts
- [x] eMMC boot (tested)
- [ ] SD card boot (testing needed)
- [ ] Camera support (ISP drivers)
- [ ] Hardware video encoding/decoding
- [ ] Qt/Wayland graphics stack
- [ ] OTA update support
- [ ] Custom BSP layer separation

---

**Made with ❤️ for the Luckfox Pico community**
