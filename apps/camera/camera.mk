# Shared build settings for EdgeEye camera pipeline library + tests
# Paths are anchored to this file so includes work from tests/camera/my_cam_test/.
CAMERA_MK_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
EDGEEYE_ROOT  := $(abspath $(CAMERA_MK_DIR)/../..)

include $(EDGEEYE_ROOT)/config.mk

CVI_MPI     := $(DUO_SDK)/cvi_mpi
RTSP_DIR    := $(DUO_SDK)/sophapp/prebuilt/rtsp/musl_riscv64
PARAM_FILE  := $(CVI_MPI)/mpi_param.mk
BUILD_PATH  := $(DUO_SDK)/build
CAM_DIR     := $(CAMERA_MK_DIR)
CAM_BUILD   := $(EDGEEYE_ROOT)/build/camera

ifndef CROSS_COMPILE
$(error CROSS_COMPILE not set — run: source scripts/envsetup.sh)
endif

ifeq ($(wildcard $(PARAM_FILE)),)
$(error missing $(PARAM_FILE) — set DUO_SDK_ROOT or clone duo-sdk next to edgeeye-duos)
endif

ifeq ($(wildcard $(BUILD_PATH)/.config),)
$(warning $(BUILD_PATH)/.config missing — sensor Kbuild may be incomplete; run build_middleware in SDK)
endif

export BUILD_PATH
include $(PARAM_FILE)
include $(CVI_MPI)/sample/sample.mk

COMMON_DIR := $(CVI_MPI)/sample/common
MW_PATH    := $(CVI_MPI)

COMMON_SRCS := sample_common_sys.c sample_common_platform.c sample_common_vi.c \
               sample_common_isp.c sample_common_bin.c sample_common_sensor.c \
               sample_common_vpss.c sample_common_venc.c

CAM_LIB_SRCS := cam_app_context.c \
                cam_isp_tuning.c \
                cam_pipeline_mode.c \
                cam_vi_bringup.c \
                cam_vpss_capture.c \
                cam_venc_encode.c \
                cam_rtsp_stream.c \
                cam_stream_run.c \
                cam_output_res.c

PKG_CONFIG_PATH := $(MW_PATH)/pkgconfig
MW_LIBS := $(shell PKG_CONFIG_PATH="$(PKG_CONFIG_PATH)" pkg-config --libs \
	--define-variable=mw_dir="$(MW_PATH)" cvi_common cvi_sample 2>/dev/null)

ifeq ($(MW_LIBS),)
$(warning pkg-config cvi_common/cvi_sample failed — PKG_CONFIG_PATH=$(PKG_CONFIG_PATH))
MW_LIBS := -lcvi_bin -lcvi_misc -lcvi_vdec -lcvi_venc -lcvi_vpss -lcvi_vo -lcvi_vi -lcvi_gdc -lcvi_rgn -lcvi_audio -lcvi_sys
endif

CAM_INCS := -I$(MW_INC) -I$(ISP_INC) -I$(COMMON_DIR) -I$(KERNEL_INC) \
	-I$(SENSOR_LIST_INC) -I$(MW_PATH)/3rdparty/inih \
	-I$(RTSP_DIR)/include -I$(CAM_DIR)

ifneq ($(wildcard $(BUILD_PATH)/.config),)
include $(BUILD_PATH)/.config
endif

ifeq ($(SENSOR_LIST_INC),)
$(error SENSOR_LIST_INC empty after including $(PARAM_FILE))
endif

include $(SENSOR_LIST_INC)/Kbuild
CAM_CFLAGS := $(KBUILD_DEFINES)

RTSP_LIBS := -L$(RTSP_DIR)/lib -lcvi_rtsp \
	$(RTSP_DIR)/lib/libliveMedia.a \
	$(RTSP_DIR)/lib/libgroupsock.a \
	$(RTSP_DIR)/lib/libBasicUsageEnvironment.a \
	$(RTSP_DIR)/lib/libUsageEnvironment.a

CAM_LIBS := $(MW_LIBS) -lcvi_ispd2 -lsys -lgdc -ldl -lpthread -lm -lini
CAM_LIBS += $(MW_LIB)/libvpss.a
CAM_LIBS += $(MW_PATH)/modules/bin/prebuilt/riscv64-unknown-linux-musl/libcvi_json-c.a
CAM_LIBS += $(RTSP_LIBS)

CAM_CFLAGS += $(CFLAGS) $(CAM_INCS) -Wall -Wextra

define cam_compile_rule
$(CAM_BUILD)/$(1).o: $(2) | $(CAM_BUILD)
	$$(CC) $$(CAM_CFLAGS) -o $$@ -c $$<
	@echo "  cc: $$@"
endef
