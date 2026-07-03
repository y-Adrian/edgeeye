# edgeeye_cam — 产品 RTSP 二进制
PRODUCT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
include $(PRODUCT_DIR)/../camera.mk

PRODUCT_BUILD := $(EDGEEYE_ROOT)/build/camera-product
PRODUCT_SRCS  := edgeeye_cam.c cam_sensor_setup.c
OBJS          := $(addprefix $(PRODUCT_BUILD)/,$(CAM_LIB_SRCS:.c=.o) $(COMMON_SRCS:.c=.o) $(PRODUCT_SRCS:.c=.o))
TARGET        := edgeeye_cam
OUT_BIN       := $(OUT_DIR)/$(TARGET)

.PHONY: all clean

all: $(OUT_BIN)

$(OUT_BIN): $(OBJS) $(MW_LIB)/libsys.a | $(PRODUCT_BUILD)
	@mkdir -p $(OUT_DIR)
	$(CXX) -o $@ -Wl,--start-group $(OBJS) -lsys $(MW_LIB)/libsys.a \
		-Wl,--end-group $(ELFFLAGS) $(CAM_LIBS)
	@echo "  built: $@"

$(PRODUCT_BUILD):
	@mkdir -p $(PRODUCT_BUILD)

$(PRODUCT_BUILD)/%.o: $(CAM_DIR)/%.c | $(PRODUCT_BUILD)
	$(CC) $(CAM_CFLAGS) -o $@ -c $<
	@echo "  cc: $@"

$(PRODUCT_BUILD)/%.o: $(COMMON_DIR)/%.c | $(PRODUCT_BUILD)
	$(CC) $(CAM_CFLAGS) -o $@ -c $<
	@echo "  cc: $@"

$(PRODUCT_BUILD)/%.o: $(PRODUCT_DIR)/%.c | $(PRODUCT_BUILD)
	$(CC) $(CAM_CFLAGS) -o $@ -c $<
	@echo "  cc: $@"

clean:
	rm -rf $(PRODUCT_BUILD)
	rm -f $(OUT_BIN)
