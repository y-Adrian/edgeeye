include config.mk

.PHONY: all driver app ide-index test test-board test-e2e clean clean-driver clean-app

all: driver app

driver:
	$(MAKE) -C board/driver

app:
	$(MAKE) -C apps

# 宿主机静态测试（无需板子、无需交叉编译）
test:
	sh tests/camera/run_local_tests.sh

# 板上全阶段冒烟（须 deploy 且 BOARD_IP 可达）
test-board:
	sh tests/camera/run_board_tests.sh

# Mac 一键：Docker 编译 + deploy + 板上 suite
test-e2e:
	sh tests/camera/run_e2e.sh

# Docker 内 make 后，于 macOS 宿主机执行以刷新 IDE 跳转索引
ide-index:
	python3 scripts/gen_compile_commands.py
	python3 ../scripts/merge_compile_commands.py

clean: clean-driver clean-app

clean-driver:
	$(MAKE) -C board/driver clean

clean-app:
	$(MAKE) -C apps clean
