# Makefile for AIC8800DC WiFi driver - Yocto-compatible version
# Hybrid Makefile: Kbuild for kernel build system, regular targets for command line

# Kbuild part (when called from kernel build system with KERNELRELEASE set)
ifneq ($(KERNELRELEASE),)

obj-m += aic8800_bsp/
obj-m += aic8800_fdrv/
obj-m += aic8800_btlpm/

# Platform defines
ccflags-y += -DANDROID_PLATFORM
ccflags-y += -DCONFIG_PLATFORM_ROCKCHIP

# Core driver configuration
ccflags-y += -DCONFIG_RWNX_FULLMAC
ccflags-y += -DCONFIG_BR_SUPPORT

# Device limits and constants
ccflags-y += -DNX_VIRT_DEV_MAX=4
ccflags-y += -DNX_REMOTE_STA_MAX=32
ccflags-y += -DNX_REMOTE_STA_MAX_FOR_OLD_IC=10
ccflags-y += -DNX_MU_GROUP_MAX=62
ccflags-y += -DNX_TXDESC_CNT=64
ccflags-y += -DNX_TX_MAX_RATES=4
ccflags-y += -DNX_CHAN_CTXT_CNT=3
ccflags-y += -DCONFIG_USER_MAX=1
ccflags-y += -DNX_TXQ_CNT=4

# Feature flags
ccflags-y += -DCONFIG_VENDOR_RWNX_VHT_NO80
ccflags-y += -Wno-implicit-fallthrough
ccflags-y += -Wno-unused-function
ccflags-y += -Wno-unused-variable

# Regular Makefile part (when called from command line)
else

PWD := $(shell pwd)

all: modules

modules:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

modules_install:
	$(MAKE) -C $(KDIR) M=$(PWD) modules_install

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean

.PHONY: all modules modules_install clean

endif

