#!/usr/bin/env python3
"""生成 edgeeye-duos 的 compile_commands.json（Docker make 后于宿主机执行）。

覆盖：
  - board/driver/*.c（kbuild .cmd）
  - apps/camera/* + duo-sdk cvi_mpi sample/common（MPI 头文件与跳转）
  - apps/motion、apps/sync 用户态程序

用法：
  python3 scripts/gen_compile_commands.py
  make ide-index
"""
from __future__ import annotations

import glob
import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RISCV_ROOT = os.path.dirname(REPO)
DOCKER_WORK = "/home/work"
KDIR_DOCKER = (
    "/home/work/duo-sdk/linux_5.10/build/sg2000_milkv_duos_musl_riscv64_sd"
)
DUO_SDK = os.path.join(RISCV_ROOT, "duo-sdk")
CVI_MPI = os.path.join(DUO_SDK, "cvi_mpi")
BUILD_CONFIG = os.path.join(DUO_SDK, "build", ".config")


def map_path(path: str) -> str:
    if path.startswith(DOCKER_WORK):
        return RISCV_ROOT + path[len(DOCKER_WORK) :]
    return path


def parse_kbuild_driver() -> list[dict]:
    kbuild_dir = os.path.join(REPO, "build", "driver")
    cmd_glob = os.path.join(kbuild_dir, ".*.o.cmd")
    cmd_files = glob.glob(cmd_glob)
    if not cmd_files:
        print(
            "warn: no build/driver/*.o.cmd — run 'make driver' in Docker first",
            file=sys.stderr,
        )
        return []

    kdir_host = map_path(KDIR_DOCKER)
    entries: list[dict] = []

    for cmdfile in sorted(cmd_files):
        with open(cmdfile, encoding="utf-8", errors="replace") as f:
            line = f.readline()
        m = re.match(r"cmd_(.+?) := (.+)", line.strip())
        if not m:
            continue
        cmd = map_path(m.group(2))
        cmd = cmd.replace(DOCKER_WORK, RISCV_ROOT)
        src_m = re.search(r" -c -o \S+ (\S+\.c)$", cmd)
        if not src_m:
            continue
        src = map_path(src_m.group(1))
        src = src.replace(f"{REPO}/build/driver/", f"{REPO}/board/driver/")
        entries.append({"directory": kdir_host, "command": cmd, "file": src})

    return entries


def parse_sensor_defines(config_path: str) -> list[str]:
    if not os.path.isfile(config_path):
        print(f"warn: missing {config_path}", file=sys.stderr)
        return []

    defs: list[str] = []
    with open(config_path, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line.startswith("CONFIG_SENSOR_") or line.startswith("#"):
                continue
            if not line.endswith("=y"):
                continue
            key = line.split("=", 1)[0]
            if "TUNING_PARAM" in key:
                continue
            macro = key.replace("CONFIG_", "", 1)
            defs.append(f"-D{macro}")
    return defs


def mpi_compile_flags() -> str:
    mw_inc = os.path.join(CVI_MPI, "include")
    isp_inc = os.path.join(CVI_MPI, "modules", "isp", "include", "cv181x")
    common_dir = os.path.join(CVI_MPI, "sample", "common")
    kernel_inc = os.path.join(
        DUO_SDK,
        "linux_5.10/build/sg2000_milkv_duos_musl_riscv64_sd/riscv/usr/include",
    )
    sensor_list_inc = os.path.join(CVI_MPI, "component", "isp", "common")
    inih_inc = os.path.join(CVI_MPI, "3rdparty", "inih")

    incs = [
        mw_inc,
        isp_inc,
        common_dir,
        kernel_inc,
        sensor_list_inc,
        inih_inc,
    ]
    inc_flags = " ".join(f"-I{p}" for p in incs)
    sensor_defs = " ".join(parse_sensor_defines(BUILD_CONFIG))

    return (
        "clang -std=gnu11 -g -Wall -Wextra -fPIC "
        "-D__CV181X__ -DOS_IS_LINUX "
        f"{sensor_defs} {inc_flags}"
    )


def mpi_sources() -> list[str]:
    cam_dir = os.path.join(REPO, "apps", "camera")
    test_dir = os.path.join(REPO, "tests", "camera", "my_cam_test")
    cam_lib = [
        "cam_app_context.c",
        "cam_isp_tuning.c",
        "cam_pipeline_mode.c",
        "cam_vi_bringup.c",
        "cam_vpss_capture.c",
        "cam_venc_encode.c",
        "cam_rtsp_stream.c",
    ]
    test_srcs = ["my_cam_test.c", "cam_test_phases.c"]
    common_dir = os.path.join(CVI_MPI, "sample", "common")
    common_names = [
        "sample_common_sys.c",
        "sample_common_platform.c",
        "sample_common_vi.c",
        "sample_common_isp.c",
        "sample_common_bin.c",
        "sample_common_sensor.c",
    ]
    sdk_samples = [
        os.path.join(CVI_MPI, "sample", "sensor_test", "sample_sensor_test.c"),
        os.path.join(DUO_SDK, "tdl_sdk", "sample_video", "sample_vi_fd.c"),
    ]
    files = [os.path.join(cam_dir, n) for n in cam_lib]
    files += [os.path.join(test_dir, n) for n in test_srcs]
    files += [os.path.join(common_dir, n) for n in common_names]
    files += [p for p in sdk_samples if os.path.isfile(p)]
    return files


def parse_mpi_apps() -> list[dict]:
    flags = mpi_compile_flags()
    cam_build = os.path.join(REPO, "build", "camera")
    entries: list[dict] = []

    for src in mpi_sources():
        obj = os.path.join(cam_build, os.path.basename(src) + ".o")
        cmd = f"{flags} -c -o {obj} {src}"
        entries.append({"directory": cam_build, "command": cmd, "file": src})

    return entries


def parse_user_apps() -> list[dict]:
    include = os.path.join(REPO, "include")
    flags = f"clang -Wall -Wextra -static -O2 -g -I{include}"
    entries: list[dict] = []

    for sub in ("motion", "sync"):
        app_dir = os.path.join(REPO, "apps", sub)
        for src in sorted(glob.glob(os.path.join(app_dir, "*.c"))):
            obj = os.path.join(REPO, "build", "app", os.path.basename(src) + ".o")
            cmd = f"{flags} -c -o {obj} {src}"
            entries.append({"directory": app_dir, "command": cmd, "file": src})

    return entries


def main() -> int:
    entries: list[dict] = []
    entries.extend(parse_kbuild_driver())
    entries.extend(parse_mpi_apps())
    entries.extend(parse_user_apps())

    if not entries:
        print("parsed 0 compile entries", file=sys.stderr)
        return 1

    out = os.path.join(REPO, "compile_commands.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(entries, f, indent=2)
        f.write("\n")

    print(f"wrote {out} ({len(entries)} entries)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
