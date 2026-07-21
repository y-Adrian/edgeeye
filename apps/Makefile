include ../config.mk

CC         := $(CROSS_COMPILE)gcc
CFLAGS     := -Wall -Wextra -static -O2 -I$(ROOT_DIR)/include
BUILD_DIR  := $(ROOT_DIR)/build/app
OUT_DIR    := $(ROOT_DIR)/output
SENSOR_CFG := $(ROOT_DIR)/configs/sensor

MOTION_SRCS := $(wildcard $(CURDIR)/motion/*.c)
MOTION_BINS := $(patsubst $(CURDIR)/motion/%.c,$(BUILD_DIR)/%,$(MOTION_SRCS))
SYNC_SRCS   := $(wildcard $(CURDIR)/sync/*.c)
SYNC_BINS   := $(patsubst $(CURDIR)/sync/%.c,$(BUILD_DIR)/%,$(SYNC_SRCS))
AI_SRCS     := $(wildcard $(CURDIR)/ai/*.c)
AI_BINS     := $(patsubst $(CURDIR)/ai/%.c,$(BUILD_DIR)/%,$(AI_SRCS))
APP_BINS    := $(MOTION_BINS) $(SYNC_BINS) $(AI_BINS)

.PHONY: all clean install_sensor camera

all: $(BUILD_DIR) $(APP_BINS) camera install_sensor
	@cp $(APP_BINS) $(OUT_DIR)/ 2>/dev/null || true

camera:
	$(MAKE) -C $(ROOT_DIR)/apps/camera/bin
	$(MAKE) -C $(ROOT_DIR)/tests/camera/my_cam_test

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/%: $(CURDIR)/motion/%.c
	$(CC) $(CFLAGS) -o $@ $<
	@echo "  built: $@"

$(BUILD_DIR)/%: $(CURDIR)/sync/%.c
	$(CC) $(CFLAGS) -o $@ $<
	@echo "  built: $@"

$(BUILD_DIR)/%: $(CURDIR)/ai/%.c
	$(CC) $(CFLAGS) -o $@ $<
	@echo "  built: $@"

install_sensor:
	@mkdir -p $(OUT_DIR)/stream
	@cp $(SENSOR_CFG)/*.ini $(OUT_DIR)/stream/ 2>/dev/null || true

clean:
	rm -rf $(BUILD_DIR)
	$(MAKE) -C camera clean 2>/dev/null || true
	$(MAKE) -C $(ROOT_DIR)/tests/camera/my_cam_test clean 2>/dev/null || true
	@rm -f $(OUT_DIR)/motion_detect $(OUT_DIR)/motion_detect_v4l2 $(OUT_DIR)/motion_recorder $(OUT_DIR)/sync_probe $(OUT_DIR)/my_cam_test $(OUT_DIR)/edgeeye_cam $(OUT_DIR)/ai_event_log $(OUT_DIR)/ai_grab_frame 2>/dev/null || true
	@rm -rf $(OUT_DIR)/stream 2>/dev/null || true
