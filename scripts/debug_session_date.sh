#!/bin/sh
# debug_session_date.sh — DEBUG_SESSION 变更记录用日期（互联网优先，Asia/Shanghai）
# 用法：sh scripts/debug_session_date.sh
# 成功时 stdout 输出 YYYY-MM-DD；stderr 注明来源；失败时 local fallback 并 warn。
set -e

SOURCE=""
DATE=""

# JSON API：datetime / dateTime 字段（已是日历日期或含 Shanghai 时区）
try_json() {
	url=$1
	pattern=$2
	name=$3
	out=$(
		curl -fsS --max-time 8 "$url" 2>/dev/null \
		| sed -n "$pattern" \
		| head -1
	)
	if [ -n "$out" ]; then
		DATE=$out
		SOURCE=$name
	fi
}

try_json \
	"https://worldtimeapi.org/api/timezone/Asia/Shanghai" \
	's/.*"datetime":"\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\).*/\1/p' \
	"worldtimeapi.org"

if [ -z "$DATE" ]; then
	try_json \
		"https://timeapi.io/api/Time/current/zone?timeZone=Asia/Shanghai" \
		's/.*"dateTime":"\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)".*/\1/p' \
		"timeapi.io"
fi

# HTTP Date 头（GMT）；转为 Asia/Shanghai 日历日
if [ -z "$DATE" ]; then
	for url in https://www.google.com https://www.baidu.com https://www.cloudflare.com; do
		rfc=$(
			curl -fsSI --max-time 8 "$url" 2>/dev/null \
			| sed -n 's/^[Dd]ate: \(.*\)/\1/p' \
			| head -1
		)
		[ -z "$rfc" ] && continue
		# 先解析为 UTC 时间戳，再格式化为 Asia/Shanghai 日历日
		ts=$(date -j -u -f "%a, %d %b %Y %H:%M:%S %Z" "$rfc" "+%s" 2>/dev/null) || ts=
		if [ -n "$ts" ]; then
			DATE=$(TZ=Asia/Shanghai date -r "$ts" "+%Y-%m-%d" 2>/dev/null) || DATE=
		fi
		if [ -z "$DATE" ]; then
			DATE=$(TZ=Asia/Shanghai date -d "$rfc" "+%Y-%m-%d" 2>/dev/null) || DATE=
		fi
		if [ -n "$DATE" ]; then
			SOURCE="$url Date→Asia/Shanghai"
			break
		fi
	done
fi

if [ -z "$DATE" ]; then
	DATE=$(TZ=Asia/Shanghai date +%Y-%m-%d)
	SOURCE="local TZ=Asia/Shanghai (network unavailable)"
	echo "warn: $SOURCE" >&2
else
	echo "info: date from $SOURCE" >&2
fi

echo "$DATE"
