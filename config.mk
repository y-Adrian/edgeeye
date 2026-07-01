# 公共编译配置 — Docker 内先 source /home/work/init_env.sh

ROOT_DIR := $(realpath $(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

ARCH          := riscv
CROSS_COMPILE := riscv64-unknown-linux-musl-
KDIR          := /home/work/duo-sdk/linux_5.10/build/sg2000_milkv_duos_musl_riscv64_sd

OUT_DIR       := $(shell realpath $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/output)

BOARD_IP      := 192.168.42.1
BOARD_USER    := root
BOARD_DIR     := /root
