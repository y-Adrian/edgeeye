include ../config.mk

CC         := $(CROSS_COMPILE)gcc
CFLAGS     := -Wall -Wextra -static -O2 -I$(ROOT_DIR)/include
BUILD_DIR  := $(ROOT_DIR)/build/app
OUT_DIR    := $(ROOT_DIR)/output
STREAM_SCRIPTS := $(CURDIR)/stream
STREAM_CFG     := $(ROOT_DIR)/configs/stream
SENSOR_CFG     := $(ROOT_DIR)/configs/sensor

MOTION_SRCS := $(wildcard $(CURDIR)/motion/*.c)
MOTION_BINS := $(patsubst $(CURDIR)/motion/%.c,$(BUILD_DIR)/%,$(MOTION_SRCS))
SYNC_SRCS   := $(wildcard $(CURDIR)/sync/*.c)
SYNC_BINS   := $(patsubst $(CURDIR)/sync/%.c,$(BUILD_DIR)/%,$(SYNC_SRCS))
APP_BINS    := $(MOTION_BINS) $(SYNC_BINS)

.PHONY: all clean install_stream camera

all: $(BUILD_DIR) $(APP_BINS) camera install_stream
	@cp $(APP_BINS) $(OUT_DIR)/ 2>/dev/null || true

camera:
	$(MAKE) -C camera

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/%: $(CURDIR)/motion/%.c
	$(CC) $(CFLAGS) -o $@ $<
	@echo "  built: $@"

$(BUILD_DIR)/%: $(CURDIR)/sync/%.c
	$(CC) $(CFLAGS) -o $@ $<
	@echo "  built: $@"

install_stream:
	@mkdir -p $(OUT_DIR)/stream
	@cp $(STREAM_CFG)/*.json $(OUT_DIR)/stream/ 2>/dev/null || true
	@cp $(SENSOR_CFG)/*.ini $(OUT_DIR)/stream/ 2>/dev/null || true
	@cp $(STREAM_SCRIPTS)/start_rtsp.sh $(STREAM_SCRIPTS)/stop_rtsp.sh $(OUT_DIR)/stream/ 2>/dev/null || true
	@chmod +x $(OUT_DIR)/stream/start_rtsp.sh $(OUT_DIR)/stream/stop_rtsp.sh 2>/dev/null || true

clean:
	rm -rf $(BUILD_DIR)
	$(MAKE) -C camera clean 2>/dev/null || true
	@rm -f $(OUT_DIR)/motion_detect $(OUT_DIR)/motion_detect_v4l2 $(OUT_DIR)/motion_recorder $(OUT_DIR)/sync_probe $(OUT_DIR)/my_cam_test 2>/dev/null || true
	@rm -rf $(OUT_DIR)/stream 2>/dev/null || true
