ifneq ($(KERNELRELEASE),)
# ── 内核构建阶段（由 kbuild 二次调用）────────────────────────────
obj-m := debris.o

debris-objs := debris_core.o debris_fops.o debris_proc.o debris_irq.o \
               debris_gpio.o debris_i2c.o debris_ov5647_regs.o debris_event.o \
               debris_platform.o

# Phase 5: mmap / poll / DMA（解锁时取消注释）
# debris-objs += debris_adv.o

else
# ── 顶层构建阶段 ──────────────────────────────────────────────────
include ../../config.mk

BUILD_DIR := $(ROOT_DIR)/build/driver
KO        ?= debris.ko

all:
	@mkdir -p $(BUILD_DIR)
	@cp $(wildcard $(CURDIR)/*.c $(CURDIR)/*.h $(CURDIR)/Makefile) $(BUILD_DIR)/
	$(MAKE) -C $(KDIR) M=$(BUILD_DIR) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) modules
	cp $(BUILD_DIR)/debris.ko $(OUT_DIR)/

clean:
	$(MAKE) -C $(KDIR) M=$(BUILD_DIR) clean 2>/dev/null || true
	rm -rf $(BUILD_DIR)
	rm -f $(OUT_DIR)/debris.ko

endif
