# EdgeEye camera learning apps — link against duo-sdk cvi_mpi (same as sample_sensor_test)
include ../../config.mk

DUO_SDK     := $(ROOT_DIR)/../duo-sdk
CVI_MPI     := $(DUO_SDK)/cvi_mpi
RTSP_DIR    := $(DUO_SDK)/sophapp/prebuilt/rtsp/musl_riscv64
PARAM_FILE  := $(CVI_MPI)/mpi_param.mk
# 须指向含 .config 的 build 目录，否则 sample_common_sensor.c 不含 GC2083/OV5647 驱动表
BUILD_PATH  := $(DUO_SDK)/build
CAM_BUILD   := $(ROOT_DIR)/build/camera

export BUILD_PATH
include $(PARAM_FILE)
include $(CVI_MPI)/sample/sample.mk

COMMON_DIR := $(CVI_MPI)/sample/common
MW_PATH    := $(CVI_MPI)

COMMON_SRCS := sample_common_sys.c sample_common_platform.c sample_common_vi.c \
               sample_common_isp.c sample_common_bin.c sample_common_sensor.c \
               sample_common_vpss.c sample_common_venc.c

CAM_SRCS := my_cam_test.c \
            cam_app_context.c \
            cam_isp_tuning.c \
            cam_pipeline_mode.c \
            cam_vi_bringup.c \
            cam_vpss_capture.c \
            cam_venc_encode.c \
            cam_rtsp_stream.c \
            cam_test_phases.c

SRCS     := $(CAM_SRCS) $(COMMON_SRCS)
OBJS     := $(addprefix $(CAM_BUILD)/,$(CAM_SRCS:.c=.o) $(COMMON_SRCS:.c=.o))

TARGET   := my_cam_test
OUT_BIN  := $(OUT_DIR)/$(TARGET)

PKG_CONFIG_PATH := $(MW_PATH)/pkgconfig
MW_LIBS := $(shell PKG_CONFIG_PATH=$(PKG_CONFIG_PATH) pkg-config --libs \
	--define-variable=mw_dir=$(MW_PATH) cvi_common cvi_sample)

INCS := -I$(MW_INC) -I$(ISP_INC) -I$(COMMON_DIR) -I$(KERNEL_INC) \
	-I$(SENSOR_LIST_INC) -I$(MW_PATH)/3rdparty/inih \
	-I$(RTSP_DIR)/include

# sample_common_sensor.c 须带 Kbuild 里的 -DSENSOR_*，否则 GetSnsObj 返回 NULL
ifneq ($(BUILD_PATH),)
include $(BUILD_PATH)/.config
endif
include $(SENSOR_LIST_INC)/Kbuild
CFLAGS += $(KBUILD_DEFINES)

RTSP_LIBS := -L$(RTSP_DIR)/lib -lcvi_rtsp \
	$(RTSP_DIR)/lib/libliveMedia.a \
	$(RTSP_DIR)/lib/libgroupsock.a \
	$(RTSP_DIR)/lib/libBasicUsageEnvironment.a \
	$(RTSP_DIR)/lib/libUsageEnvironment.a

LIBS := $(MW_LIBS) -lcvi_ispd2 -lsys -lgdc -ldl -lpthread -lm -lini
LIBS += $(MW_LIB)/libvpss.a
LIBS += $(MW_PATH)/modules/bin/prebuilt/riscv64-unknown-linux-musl/libcvi_json-c.a
LIBS += $(RTSP_LIBS)

CFLAGS += $(INCS) -Wall -Wextra

.PHONY: all clean install

all: $(OUT_BIN)

$(OUT_BIN): $(OBJS) $(MW_LIB)/libsys.a | $(CAM_BUILD)
	@mkdir -p $(OUT_DIR)
	$(CXX) -o $@ -Wl,--start-group $(OBJS) -lsys $(MW_LIB)/libsys.a \
		-Wl,--end-group $(ELFFLAGS) $(LIBS)
	@echo "  built: $@"

$(CAM_BUILD):
	@mkdir -p $(CAM_BUILD)

$(CAM_BUILD)/%.o: %.c | $(CAM_BUILD)
	$(CC) $(CFLAGS) -o $@ -c $<
	@echo "  cc: $@"

$(CAM_BUILD)/%.o: $(COMMON_DIR)/%.c | $(CAM_BUILD)
	$(CC) $(CFLAGS) -o $@ -c $<
	@echo "  cc: $@"

clean:
	rm -rf $(CAM_BUILD)
	rm -f $(OUT_BIN)

install: all
