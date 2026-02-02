# Luckfox Pico Yocto Project

[![Yocto Project](https://img.shields.io/badge/Yocto-5.1%20Scarthgap-blue)](https://www.yoctoproject.org/)
[![License](https://img.shields.io/badge/license-Mixed-green)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Rockchip%20RV1106-orange)](https://www.rock-chips.com/)

Modern Yocto/OpenEmbedded build system for **Luckfox Pico** boards based on Rockchip RV1106 SoC. This project provides a clean, maintainable alternative to the vendor SDK with full integration into the Yocto ecosystem.

## 🎯 Features

- ✅ **Yocto Scarthgap (5.1)** - Latest stable Yocto release
- ✅ **Multiple Boot Media** - eMMC (tested ✓), SD card (tested ✓), SPI NAND (tested ✓) with SDK-compatible partition layouts
- ✅ **FIT Boot Images** - Flattened Image Tree format with kernel, DTB, and ramdisk
- ✅ **U-Boot Integration** - Custom bootloader with environment configuration
- ✅ **WiFi Drivers** - AIC8800DC wireless support
- ✅ **Complete Disk Images** - Ready-to-flash `.img` files for all boot media
- ✅ **UBI/UBIFS Support** - Full UBI/UBIFS implementation for SPI NAND flash
- ✅ **SDK Compatibility** - Partition layout compatible with Luckfox SDK format
- ✅ **USB Gadget Support** - Serial console (ttyGS0) and Ethernet over USB (RNDIS)
- ✅ **Self-Contained Build** - Toolchain automatically fetched from git, no external dependencies

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

### 1. Install Yocto Dependencies

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

### 2. Clone Yocto Poky and meta-openembedded

```bash
# Create workspace directory
mkdir -p ~/luckfox-workspace/yocto-walnascar
cd ~/luckfox-workspace/yocto-walnascar

# Clone Yocto Poky (Scarthgap 5.1)
git clone -b walnascar https://github.com/yoctoproject/poky.git

# Clone meta-openembedded
git clone -b walnascar https://github.com/openembedded/meta-openembedded.git
```

### 3. Clone the Luckfox Yocto Layer

```bash
# Clone this repository
cd ~/luckfox-workspace
git clone https://github.com/zavdimka/luckfox-pico-yocto.git
```

Your directory structure should now look like:
```
~/luckfox-workspace/
├── luckfox-pico-yocto/          # This meta-layer
└── yocto-walnascar/
    ├── poky/                     # Yocto Poky (core)
    └── meta-openembedded/        # Additional OE layers
```

### 4. Initialize Build Environment

```bash
# Source the Yocto build environment
cd ~/luckfox-workspace/luckfox-pico-yocto
source ../yocto-walnascar/poky/oe-init-build-env ../yocto-walnascar/build-luckfox

# You should now be in ~/luckfox-workspace/yocto-walnascar/build-luckfox
```

This creates the build directory and initial configuration files.

### 5. Configure Build

You need to add the Luckfox layer and configure the build. Edit `conf/bblayers.conf`:

```bash
nano conf/bblayers.conf
```

Add the luckfox-pico-yocto and meta-oe layers (use your actual paths):

```bitbake
BBLAYERS ?= " \
  /home/<username>/luckfox-workspace/yocto-walnascar/poky/meta \
  /home/<username>/luckfox-workspace/yocto-walnascar/poky/meta-poky \
  /home/<username>/luckfox-workspace/yocto-walnascar/poky/meta-yocto-bsp \
  /home/<username>/luckfox-workspace/yocto-walnascar/meta-openembedded/meta-oe \
  /home/<username>/luckfox-workspace/luckfox-pico-yocto \
  "
```

Then edit `conf/local.conf` to set the machine and distro:

```bash
nano conf/local.conf
```

Add or modify these lines:

```bitbake
MACHINE ?= "luckfox-pico"  # Or luckfox-pico-sd or luckfox-pico-spi-nand
DISTRO ?= "luckfox"
```

**Note**: You can override MACHINE at build time without editing local.conf:
```bash
# Default (eMMC)
bitbake luckfox-image-minimal

# SD card
MACHINE=luckfox-pico-sd bitbake luckfox-image-minimal

# SPI NAND
MACHINE=luckfox-pico-spi-nand bitbake luckfox-image-minimal
```

### 6. Build Your First Image

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

### 6. Deploy the Image

After successful build, images will be in:
```
~/luckfox-workspace/yocto-walnascar/build-luckfox/tmp/deploy/images/<machine-name>/
```

Where `<machine-name>` is:
- `luckfox-pico` for eMMC builds
- `luckfox-pico-sd` for SD card builds
- `luckfox-pico-spi-nand` for SPI NAND builds

The main image file is: `luckfox-image-minimal-<machine-name>.img`

## 📀 Deployment Guide

### Deploy to SD Card

#### Linux

```bash
# Navigate to the images directory
cd ~/luckfox-workspace/yocto-walnascar/build-luckfox/tmp/deploy/images/luckfox-pico-sd/

# Find your SD card device (BE CAREFUL!)
lsblk

# Flash the image (replace /dev/sdX with your SD card device)
sudo dd if=luckfox-image-minimal-luckfox-pico-sd.img of=/dev/sdX bs=4M status=progress conv=fsync
sudo sync

# Safely remove the SD card
sudo eject /dev/sdX
```

#### Windows

Use [win32diskimager](https://sourceforge.net/projects/win32diskimager/) :
1. Download and install win32diskimager
2. Select the `.img` file
3. Select your SD card
4. Click "Write"

### Deploy to eMMC/SPI NAND Flash

For eMMC and SPI NAND, you need to use Rockchip `upgrade_tool`. The board must be in **MaskROM** mode.

#### Prerequisites

1. **Install Rockchip upgrade_tool**

   Download from [Luckfox Github](https://github.com/LuckfoxTECH/luckfox-pico/tree/main/tools/windows/SocToolKit/bin/windows):
   
   - **Linux**: `upgrade_tool` (Linux version)
   - **Windows**: `upgrade_tool.exe` (Windows version)
   
   Both use the same commands (just add `.exe` on Windows).

2. **Put Board in MaskROM Mode**

   - Power off the board
   - Short the MaskROM pins (or hold BOOT button if available)
   - Connect USB cable to PC
   - Power on the board
   - Release the short/button after 2 seconds

3. **Verify Connection**

   ```bash
   # Linux
   lsusb | grep Rockchip
   # Should show: Bus XXX Device XXX: ID 2207:110b Fuzhou Rockchip Electronics Company
   
   # Check with upgrade_tool
   sudo upgrade_tool ld  # Linux
   upgrade_tool.exe ld   # Windows
   # Should show: Found one MASKROM device
   ```

#### Standard Flash Procedure

Navigate to your build images directory:
```bash
# Linux
cd ~/luckfox-workspace/yocto-walnascar/build-luckfox/tmp/deploy/images/<machine-name>/

Where `<machine-name>` is `luckfox-pico` (eMMC) or `luckfox-pico-spi-nand` (SPI NAND).

**Step 1: Upload bootloader**
```bash
# Linux
sudo upgrade_tool db download.bin

# Windows
upgrade_tool.exe db download.bin
```

The `download.bin` is the MiniLoaderAll bootloader (find in your SDK or build output).

**Step 2: Erase flash (SPI NAND only)**

For **SPI NAND** flash, erase before first flash or after partition changes:
```bash
# For 128MB SPI NAND flash
sudo upgrade_tool EL 0 8000000     # Linux
upgrade_tool.exe EL 0 8000000      # Windows

# For 256MB SPI NAND flash
sudo upgrade_tool EL 0 10000000    # Linux
upgrade_tool.exe EL 0 10000000     # Windows
```

**Skip this step for eMMC** - erasing eMMC is not necessary and may take a very long time.

**Step 3: Write the image**
```bash
# Linux - eMMC
sudo upgrade_tool wl 0 luckfox-image-minimal-luckfox-pico.img

# Linux - SPI NAND
sudo upgrade_tool wl 0 luckfox-image-minimal-luckfox-pico-spi-nand.img

# Windows - eMMC
upgrade_tool.exe wl 0 luckfox-image-minimal-luckfox-pico.img

# Windows - SPI NAND
upgrade_tool.exe wl 0 luckfox-image-minimal-luckfox-pico-spi-nand.img
```

**Step 4: Reset the device**
```bash
# Linux
sudo upgrade_tool rd

# Windows
upgrade_tool.exe rd
```

The device will reboot automatically.

#### Complete Example - eMMC

```bash
# Linux
cd ~/luckfox-workspace/yocto-walnascar/build-luckfox/tmp/deploy/images/luckfox-pico/
sudo upgrade_tool db download.bin
sudo upgrade_tool wl 0 luckfox-image-minimal-luckfox-pico.img
sudo upgrade_tool rd

# Windows
cd C:\path\to\images\luckfox-pico\
upgrade_tool.exe db download.bin
upgrade_tool.exe wl 0 luckfox-image-minimal-luckfox-pico.img
upgrade_tool.exe rd
```

#### Complete Example - SPI NAND (256MB)

```bash
# Linux
cd ~/luckfox-workspace/yocto-walnascar/build-luckfox/tmp/deploy/images/luckfox-pico-spi-nand/
sudo upgrade_tool db download.bin
sudo upgrade_tool EL 0 10000000
sudo upgrade_tool wl 0 luckfox-image-minimal-luckfox-pico-spi-nand.img
sudo upgrade_tool rd

# Windows
cd C:\path\to\images\luckfox-pico-spi-nand\
upgrade_tool.exe db download.bin
upgrade_tool.exe EL 0 10000000
upgrade_tool.exe wl 0 luckfox-image-minimal-luckfox-pico-spi-nand.img
upgrade_tool.exe rd
```

### Verify Deployment

After flashing:

1. **Power cycle the board** (disconnect and reconnect power)
2. **Connect to serial console** (115200 8N1):
   - USB serial: `/dev/ttyUSB0` (Linux) or `COMx` (Windows)
   - After boot: `/dev/ttyGS0` (USB gadget serial console)
3. **Login**: 
   - Username: `root`
   - Password: (none - press Enter)
4. **Check boot**:
   ```bash
   # Check kernel version
   uname -a
   
   # Check mounted filesystems
   mount
   
   # Check storage
   df -h
   ```

### Serial Console Access

The system provides multiple serial console options:

- **ttyFIQ0**: Debug serial port (hardware UART, 115200 8N1)
- **ttyGS0**: USB gadget serial console (USB ACM, appears after boot)

To connect via USB gadget serial (after boot):
```bash
# Linux
sudo minicom -D /dev/ttyACM0 -b 115200

# Or using screen
sudo screen /dev/ttyACM0 115200

# Windows: Use PuTTY, TeraTerm, or similar
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
│   └── toolchain/                     # Rockchip ARM toolchain (auto-fetched from git)
│       └── arm-rockchip830-toolchain-native.bb  # GCC 8.3.0 + uclibc toolchain
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

#### eMMC (default) ✅ Tested & Working

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

### Python locale errors

```bash
sudo locale-gen en_US.UTF-8
export LC_ALL=en_US.UTF-8
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
- [x] SD card boot (tested)
- [x] SPI nand boot (tested)
- [ ] Dual boot
- [ ] OTA update support
- [ ] Custom BSP layer separation

---

**Made with ❤️ for the Luckfox Pico community**
