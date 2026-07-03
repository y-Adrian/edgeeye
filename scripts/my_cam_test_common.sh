# my_cam_test_common.sh — 验收脚本公共函数（须用 . 引入，勿直接执行）
#
# 提供：
#   my_cam_resolve_sensor SENSOR   → 设置 INI PQ PAT
#   my_cam_stop_media              → 停媒体进程（不误杀 test_my_cam_test*.sh）
#   my_cam_link_sensor             → 软链 sensor_cfg.ini 与 cvi_sdr_bin

my_cam_resolve_sensor() {
	SENSOR="$1"

	case "$SENSOR" in
	gc2083|GC2083|j1|J1)
		INI=/mnt/data/sensor_cfg_GC2083.ini
		PQ=cvi_sdr_bin_GC2083
		PAT=GC2083
		YUV_W=1920
		YUV_H=1080
		;;
	ov5647|OV5647|j2|J2)
		INI=/mnt/data/sensor_cfg_OV5647_J2.ini
		PQ=cvi_sdr_bin_OV5647.bin
		PAT=OV5647
		YUV_W=1920
		YUV_H=1080
		;;
	*)
		echo "unknown sensor: $SENSOR (use gc2083 or ov5647)"
		return 1
		;;
	esac
	return 0
}

my_cam_stop_media() {
	# 只匹配媒体二进制；勿用裸 my_cam_test，否则会命中 test_my_cam_test*.sh 自杀
	ps | grep -v grep | grep -v test_my_cam_test | \
		grep -E '/my_cam_test[[:space:]]|/sample_vi|rtsp_server|camera-test' | \
		awk '{print $1}' | while read -r p; do
			[ -n "$p" ] || continue
			kill "$p" 2>/dev/null || true
		done

	if command -v pidof >/dev/null 2>&1; then
		for name in my_cam_test sample_vi rtsp_server camera-test; do
			for p in $(pidof "$name" 2>/dev/null); do
				kill "$p" 2>/dev/null || true
			done
		done
	fi

	sleep 2
	rmmod debris 2>/dev/null || true
}

# 双摄前深度清理（停 vendor RTSP / 安防栈），仍不够时需 reboot
my_cam_stop_media_deep() {
	my_cam_stop_media
	if [ -x /root/stop_security.sh ]; then
		sh /root/stop_security.sh 2>/dev/null || true
	fi
	if [ -x /root/stream/stop_rtsp.sh ]; then
		sh /root/stream/stop_rtsp.sh 2>/dev/null || true
	elif [ -x /root/stop_rtsp.sh ]; then
		sh /root/stop_rtsp.sh 2>/dev/null || true
	fi
	if [ -f /tmp/my_cam_test_rtsp.pid ]; then
		kill "$(cat /tmp/my_cam_test_rtsp.pid)" 2>/dev/null || true
		rm -f /tmp/my_cam_test_rtsp.pid
	fi
	sleep 3
}

my_cam_resolve_dual_sensor() {
	INI=/mnt/data/sensor_cfg_GC2083_OV5647_dual.ini
	PAT_GC2083=GC2083
	PAT_OV5647=OV5647

	if [ ! -f "$INI" ] && [ -f /root/stream/sensor_cfg_GC2083_OV5647_dual.ini ]; then
		cp /root/stream/sensor_cfg_GC2083_OV5647_dual.ini "$INI"
	fi
	if [ ! -f "$INI" ]; then
		echo "missing $INI (deploy configs/sensor/ or stream/)"
		return 1
	fi
	return 0
}

my_cam_link_dual_sensor() {
	my_cam_resolve_dual_sensor || return 1
	ln -sf "$INI" /mnt/data/sensor_cfg.ini
	if readlink -f /mnt/data/sensor_cfg.ini >/dev/null 2>&1; then
		echo "sensor_cfg -> $(readlink -f /mnt/data/sensor_cfg.ini)"
	else
		echo "sensor_cfg -> $(readlink /mnt/data/sensor_cfg.ini)"
	fi
	echo "PQ: pipe0<-/mnt/cfg/param/cvi_sdr_bin_GC2083"
	echo "PQ: pipe1<-/mnt/cfg/param/cvi_sdr_bin_OV5647.bin (my_cam_test loads per pipe)"
	[ -f /mnt/cfg/param/cvi_sdr_bin_GC2083 ] || [ -L /mnt/cfg/param/cvi_sdr_bin_GC2083 ] || {
		echo "missing /mnt/cfg/param/cvi_sdr_bin_GC2083"
		return 1
	}
	[ -f /mnt/cfg/param/cvi_sdr_bin_OV5647.bin ] || [ -L /mnt/cfg/param/cvi_sdr_bin_OV5647.bin ] || {
		echo "missing /mnt/cfg/param/cvi_sdr_bin_OV5647.bin"
		return 1
	}
	grep -E 'dev_num|name|bus_id' /mnt/data/sensor_cfg.ini || true
}

my_cam_link_sensor() {
	ln -sf "$INI" /mnt/data/sensor_cfg.ini
	ln -sf "$PQ" /mnt/cfg/param/cvi_sdr_bin
	if readlink -f /mnt/data/sensor_cfg.ini >/dev/null 2>&1; then
		echo "sensor_cfg -> $(readlink -f /mnt/data/sensor_cfg.ini)"
	else
		echo "sensor_cfg -> $(readlink /mnt/data/sensor_cfg.ini)"
	fi
	echo "cvi_sdr_bin -> $(readlink /mnt/cfg/param/cvi_sdr_bin)"
}

# 从 deploy 的 /root/stream/ 同步 sensor ini 到 /mnt/data（缺失时）
my_cam_install_sensor_configs() {
	mkdir -p /mnt/data
	for ini in \
		sensor_cfg_GC2083.ini \
		sensor_cfg_OV5647_J2.ini \
		sensor_cfg_GC2083_OV5647_dual.ini \
		sensor_cfg_OV5647_dual.ini
	do
		if [ ! -f "/mnt/data/$ini" ] && [ -f "/root/stream/$ini" ]; then
			cp "/root/stream/$ini" "/mnt/data/$ini"
			echo "installed /mnt/data/$ini <- /root/stream/$ini"
		fi
	done
}

my_cam_assert_bin() {
	BIN="${MY_CAM_TEST:-/root/my_cam_test}"
	if [ ! -x "$BIN" ]; then
		echo "missing $BIN — run: cd edgeeye-duos && make app && ./deploy"
		return 1
	fi
	return 0
}

# 清理 /tmp 抓帧产物，避免 tmpfs 满
my_cam_tmp_cleanup() {
	rm -f /tmp/*.yuv /tmp/*.h264 /tmp/my_cam_test_p*.log /tmp/my_cam_test.log 2>/dev/null || true
}

my_cam_assert_log() {
	pat="$1"
	log="$2"
	msg="${3:-$pat}"
	if grep -q "$pat" "$log" 2>/dev/null; then
		return 0
	fi
	echo "FAIL: log missing '$msg'"
	return 1
}

my_cam_assert_file_min() {
	path="$1"
	min="$2"
	if [ ! -f "$path" ]; then
		echo "FAIL: missing $path"
		return 1
	fi
	bytes=$(wc -c <"$path")
	if [ "$bytes" -lt "$min" ]; then
		echo "FAIL: $path too small ($bytes < $min)"
		return 1
	fi
	echo "OK: $path size=$bytes bytes (min $min)"
	return 0
}

my_cam_reboot_if_requested() {
	if [ "${MY_CAM_REBOOT:-0}" = 1 ]; then
		echo "rebooting board (MY_CAM_REBOOT=1)..."
		reboot
	fi
}
