include config.mk

.PHONY: all driver app ide-index clean clean-driver clean-app

all: driver app

driver:
	$(MAKE) -C board/driver

app:
	$(MAKE) -C apps

# Docker 内 make 后，于 macOS 宿主机执行以刷新 IDE 跳转索引
ide-index:
	python3 scripts/gen_compile_commands.py
	python3 ../scripts/merge_compile_commands.py

clean: clean-driver clean-app

clean-driver:
	$(MAKE) -C board/driver clean

clean-app:
	$(MAKE) -C apps clean
