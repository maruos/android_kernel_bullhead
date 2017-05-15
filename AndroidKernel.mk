# Modified from original AOSP version for in-tree builds with Maru OS

#Android makefile to build kernel as a part of Android Build
PERL		= perl

KERNEL_LOCAL_PATH := $(call my-dir)

KERNEL_TARGET := $(strip $(INSTALLED_KERNEL_TARGET))
ifeq ($(KERNEL_TARGET),)
INSTALLED_KERNEL_TARGET := $(PRODUCT_OUT)/kernel
endif

TARGET_KERNEL_ARCH := $(strip $(TARGET_KERNEL_ARCH))
ifeq ($(TARGET_KERNEL_ARCH),)
KERNEL_ARCH := arm
else
KERNEL_ARCH := $(TARGET_KERNEL_ARCH)
endif

# Force 32-bit binder IPC for 64bit kernel with 32bit userspace
ifeq ($(KERNEL_ARCH),arm64)
ifeq ($(TARGET_ARCH),arm)
KERNEL_CONFIG_OVERRIDE := CONFIG_ANDROID_BINDER_IPC_32BIT=y
endif
endif

TARGET_KERNEL_CROSS_COMPILE_PREFIX := $(strip $(TARGET_KERNEL_CROSS_COMPILE_PREFIX))
ifeq ($(TARGET_KERNEL_CROSS_COMPILE_PREFIX),)
KERNEL_CROSS_COMPILE := aarch64-linux-android-
else
KERNEL_CROSS_COMPILE := $(TARGET_KERNEL_CROSS_COMPILE_PREFIX)
endif

ifeq ($(TARGET_PREBUILT_KERNEL),)

KERNEL_GCC_NOANDROID_CHK := $(shell (echo "int main() {return 0;}" | $(KERNEL_CROSS_COMPILE)gcc -E -mno-android - > /dev/null 2>&1 ; echo $$?))
ifeq ($(strip $(KERNEL_GCC_NOANDROID_CHK)),0)
KERNEL_CFLAGS := KCFLAGS=-mno-android
endif

KERNEL_OUT := $(TARGET_OUT_INTERMEDIATES)/KERNEL_OBJ
KERNEL_CONFIG := $(KERNEL_OUT)/.config

ifeq ($(KERNEL_DEFCONFIG)$(wildcard $(KERNEL_CONFIG)),)
$(error Kernel configuration not defined, cannot build kernel)
else

ifeq ($(TARGET_USES_UNCOMPRESSED_KERNEL),true)
$(info Using uncompressed kernel)
TARGET_PREBUILT_INT_KERNEL := $(KERNEL_OUT)/arch/$(KERNEL_ARCH)/boot/Image
else
TARGET_PREBUILT_INT_KERNEL := $(KERNEL_OUT)/arch/$(KERNEL_ARCH)/boot/Image.gz
endif

ifeq ($(TARGET_KERNEL_APPEND_DTB), true)
$(info Using appended DTB)
TARGET_PREBUILT_INT_KERNEL := $(TARGET_PREBUILT_INT_KERNEL)-dtb
endif

TARGET_PREBUILT_KERNEL := $(TARGET_PREBUILT_INT_KERNEL)

$(info $(TARGET_PREBUILT_INT_KERNEL))
$(info $(KERNEL_CONFIG))

$(KERNEL_OUT):
	mkdir -p $(KERNEL_OUT)

$(KERNEL_CONFIG): $(KERNEL_OUT)
	$(MAKE) -C $(KERNEL_LOCAL_PATH) O=../../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) CROSS_COMPILE=$(KERNEL_CROSS_COMPILE) $(KERNEL_DEFCONFIG)
	$(hide) if [ ! -z "$(KERNEL_CONFIG_OVERRIDE)" ]; then \
			echo "Overriding kernel config with '$(KERNEL_CONFIG_OVERRIDE)'"; \
			echo $(KERNEL_CONFIG_OVERRIDE) >> $(KERNEL_OUT)/.config; \
			$(MAKE) -C $(KERNEL_LOCAL_PATH) O=../../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) CROSS_COMPILE=$(KERNEL_CROSS_COMPILE) oldconfig; fi

$(TARGET_PREBUILT_INT_KERNEL): $(KERNEL_OUT) $(KERNEL_CONFIG)
	$(hide) echo "Building kernel..."
	$(hide) rm -rf $(KERNEL_OUT)/arch/$(KERNEL_ARCH)/boot/dts
	$(MAKE) -C $(KERNEL_LOCAL_PATH) O=../../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) CROSS_COMPILE=$(KERNEL_CROSS_COMPILE) $(KERNEL_CFLAGS)

kerneltags: $(KERNEL_OUT) $(KERNEL_CONFIG)
	$(MAKE) -C $(KERNEL_LOCAL_PATH) O=../../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) CROSS_COMPILE=$(KERNEL_CROSS_COMPILE) tags

kernelconfig: $(KERNEL_OUT) $(KERNEL_CONFIG)
	env KCONFIG_NOTIMESTAMP=true \
	     $(MAKE) -C $(KERNEL_LOCAL_PATH) O=../../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) CROSS_COMPILE=$(KERNEL_CROSS_COMPILE) menuconfig
	env KCONFIG_NOTIMESTAMP=true \
	     $(MAKE) -C $(KERNEL_LOCAL_PATH) O=../../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) CROSS_COMPILE=$(KERNEL_CROSS_COMPILE) savedefconfig
	cp $(KERNEL_OUT)/defconfig kernel/arch/$(KERNEL_ARCH)/configs/$(KERNEL_DEFCONFIG)

kernelclean:
	$(MAKE) -C $(KERNEL_LOCAL_PATH) O=../../$(KERNEL_OUT) ARCH=$(KERNEL_ARCH) CROSS_COMPILE=$(KERNEL_CROSS_COMPILE) clean
	$(hide) if [ -f "$(KERNEL_CONFIG)" ] ; then \
			rm -r $(KERNEL_CONFIG); fi
	$(hide) if [ -d "$(KERNEL_HEADERS_INSTALL)" ] ; then \
			rm -r $(KERNEL_HEADERS_INSTALL); fi

endif
endif
