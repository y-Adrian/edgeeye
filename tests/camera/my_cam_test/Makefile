# my_cam_test — board acceptance binary (links apps/camera pipeline lib sources)
TEST_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
include $(TEST_DIR)/../../../apps/camera/camera.mk

TEST_BUILD  := $(EDGEEYE_ROOT)/build/camera-test
TEST_SRCS   := my_cam_test.c cam_test_phases.c
OBJS        := $(addprefix $(TEST_BUILD)/,$(CAM_LIB_SRCS:.c=.o) $(COMMON_SRCS:.c=.o) $(TEST_SRCS:.c=.o))
TARGET      := my_cam_test
OUT_BIN     := $(OUT_DIR)/$(TARGET)

.PHONY: all clean

all: $(OUT_BIN)

$(OUT_BIN): $(OBJS) $(MW_LIB)/libsys.a | $(TEST_BUILD)
	@mkdir -p $(OUT_DIR)
	$(CXX) -o $@ -Wl,--start-group $(OBJS) -lsys $(MW_LIB)/libsys.a \
		-Wl,--end-group $(ELFFLAGS) $(CAM_LIBS)
	@echo "  built: $@"

$(TEST_BUILD):
	@mkdir -p $(TEST_BUILD)

$(TEST_BUILD)/%.o: $(CAM_DIR)/%.c | $(TEST_BUILD)
	$(CC) $(CAM_CFLAGS) -o $@ -c $<
	@echo "  cc: $@"

$(TEST_BUILD)/%.o: $(COMMON_DIR)/%.c | $(TEST_BUILD)
	$(CC) $(CAM_CFLAGS) -o $@ -c $<
	@echo "  cc: $@"

$(TEST_BUILD)/%.o: $(TEST_DIR)/%.c | $(TEST_BUILD)
	$(CC) $(CAM_CFLAGS) -I$(TEST_DIR) -o $@ -c $<
	@echo "  cc: $@"

clean:
	rm -rf $(TEST_BUILD)
	rm -f $(OUT_BIN)
