#!/bin/bash
# envsetup.sh — EdgeEye 交叉编译环境初始化
#
# 板型 / SDK 基线见 docs/DEVELOPMENT.md §0
#   milkv-duos-musl-riscv64-sd  ·  Linux 5.10  ·  gcc 10.2.0 musl
#
# 每次进入 Docker 或新开 shell 后执行（须在 bash 下 source）：
#   cd edgeeye-duos
#   source scripts/envsetup.sh
#
# 依赖 Milk-V duo-sdk，默认与 edgeeye-duos 同级目录：
#   parent/edgeeye-duos/
#   parent/duo-sdk/
# 或通过环境变量指定：export DUO_SDK_ROOT=/path/to/duo-sdk
#
# 成功后导出 CROSS_COMPILE、CC、KERNEL_OUTPUT_FOLDER 等，即可 make app。

_EDGEEYE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export EDGEEYE_ROOT="${_EDGEEYE_ROOT}"

if [ -n "${DUO_SDK_ROOT}" ]; then
	_SDK_ROOT="${DUO_SDK_ROOT}"
elif [ -d "${_EDGEEYE_ROOT}/../duo-sdk" ]; then
	_SDK_ROOT="$(cd "${_EDGEEYE_ROOT}/../duo-sdk" && pwd)"
else
	echo "ERROR: duo-sdk not found." >&2
	echo "" >&2
	echo "EdgeEye 编译需要 Milk-V Buildroot SDK（duo-sdk），与本仓库并列放置：" >&2
	echo "  your-workspace/" >&2
	echo "    edgeeye-duos/    ← 本仓库" >&2
	echo "    duo-sdk/         ← Milk-V SDK" >&2
	echo "" >&2
	echo "获取 SDK：见 docs/DEVELOPMENT.md「准备 duo-sdk」" >&2
	echo "或设置：export DUO_SDK_ROOT=/path/to/duo-sdk" >&2
	return 1 2>/dev/null || exit 1
fi

export DUO_SDK_ROOT="${_SDK_ROOT}"
export TOP="${_SDK_ROOT}"

if [ ! -f "${_SDK_ROOT}/build/envsetup_milkv.sh" ]; then
	echo "ERROR: missing ${_SDK_ROOT}/build/envsetup_milkv.sh" >&2
	return 1 2>/dev/null || exit 1
fi

# shellcheck disable=SC1091
source "${_SDK_ROOT}/build/envsetup_milkv.sh" milkv-duos-musl-riscv64-sd || return 1

# envsetup 赋值但未 export；直接 make kernel-dts 会污染源码树
export KERNEL_OUTPUT_FOLDER RAMDISK_OUTPUT_FOLDER RAMDISK_OUTPUT_BASE

export CC="${CROSS_COMPILE}gcc"
export CXX="${CROSS_COMPILE}g++"
export AR="${CROSS_COMPILE}ar"
export LD="${CROSS_COMPILE}ld"

if [ -z "${KERNEL_OUTPUT_FOLDER}" ]; then
	echo "ERROR: KERNEL_OUTPUT_FOLDER is empty" >&2
	return 1 2>/dev/null || exit 1
fi

if [ ! -f "${KERNEL_PATH}/${KERNEL_OUTPUT_FOLDER}/.config" ]; then
	echo "WARN: kernel not configured yet — edgeeye_cam build usually OK; run build_kernel for DTS" >&2
fi

echo "env ready: EDGEEYE_ROOT=${EDGEEYE_ROOT}"
echo "env ready: DUO_SDK_ROOT=${DUO_SDK_ROOT}"
echo "env ready: MILKV_BOARD=milkv-duos-musl-riscv64-sd"
echo "env ready: KERNEL_OUTPUT_FOLDER=${KERNEL_OUTPUT_FOLDER}"
echo "env ready: CC=${CC}"

if [ -d "${_SDK_ROOT}/.git" ]; then
	_SDK_REV="$(git -C "${_SDK_ROOT}" rev-parse --short HEAD 2>/dev/null || true)"
	[ -n "${_SDK_REV}" ] && echo "env ready: DUO_SDK_REV=${_SDK_REV}"
fi
