# Makefile for AIC8800DC WiFi driver - Yocto-compatible version
# Hybrid Makefile: Kbuild for kernel build system, regular targets for command line

# Kbuild part (when called from kernel build system with KERNELRELEASE set)
ifneq ($(KERNELRELEASE),)

obj-m += aic8800_bsp/
obj-m += aic8800_fdrv/
obj-m += aic8800_btlpm/

ccflags-y += -DANDROID_PLATFORM
ccflags-y += -DCONFIG_PLATFORM_ROCKCHIP

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

