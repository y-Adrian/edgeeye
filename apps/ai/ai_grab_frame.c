/* ai_grab_frame.c — EdgeEye AI 取帧（步骤 3：RTSP → 低分辨率 JPEG）
 *
 * 测试接口：--dry-run / --once；环境变量 AI_RTSP_URL / AI_FRAME_PATH / FFMPEG
 * 测试场景：cam0 RTSP 就绪时抓一帧 scale 后的 JPEG，供步骤 4 检测使用
 *
 * 用法：
 *   ./ai_grab_frame --dry-run
 *   ./ai_grab_frame --once
 *   ./ai_grab_frame --once --width 448 --height 448 --out /tmp/edgeeye_ai_frame.jpg
 */
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

#define DEFAULT_URL  "rtsp://127.0.0.1:8554/cam0"
#define DEFAULT_OUT  "/tmp/edgeeye_ai_frame.jpg"
#define DEFAULT_W    448
#define DEFAULT_H    448

static const char *resolve_ffmpeg(const char *hint)
{
	static const char *paths[] = {
		"/mnt/data/bin/ffmpeg",
		"/mnt/system/usr/bin/ffmpeg",
		"/usr/bin/ffmpeg",
		"ffmpeg",
		NULL,
	};
	int i;

	if (hint && hint[0] && access(hint, X_OK) == 0)
		return hint;
	for (i = 0; paths[i]; i++) {
		if (access(paths[i], X_OK) == 0)
			return paths[i];
	}
	return hint && hint[0] ? hint : "ffmpeg";
}

static int run_cmd(const char *cmd)
{
	int ret;

	/* system：同步执行 ffmpeg 抓帧命令 */
	ret = system(cmd);
	if (ret < 0)
		return -1;
	if (WIFEXITED(ret))
		return WEXITSTATUS(ret);
	return -1;
}

static int grab_once(const char *ffmpeg, const char *url, const char *outpath,
		     int width, int height)
{
	char cmd[1400];
	struct stat st;
	const char *timeout_bin = "";

	if (access("/usr/bin/timeout", X_OK) == 0)
		timeout_bin = "/usr/bin/timeout 60 ";

	/* 与 motion_recorder 相同：JPEG + scale；板载精简 ffmpeg 支持 image2/mjpeg/scale */
	snprintf(cmd, sizeof(cmd),
		 "%s%s -y -loglevel error -rtsp_transport tcp "
		 "-analyzeduration 2000000 -probesize 1000000 "
		 "-i '%s' -vf scale=%d:%d -frames:v 1 -q:v 5 "
		 "-f image2 '%s' 2>/dev/null",
		 timeout_bin, ffmpeg, url, width, height, outpath);

	if (run_cmd(cmd) != 0) {
		fprintf(stderr, "ai_grab_frame: ffmpeg grab failed url=%s\n", url);
		return -1;
	}
	/* stat：确认输出 JPEG 已生成且非空 */
	if (stat(outpath, &st) != 0 || st.st_size < 64) {
		fprintf(stderr, "ai_grab_frame: bad output %s\n", outpath);
		return -1;
	}

	printf("ai_grab_frame: ok path=%s bytes=%ld size=%dx%d url=%s\n",
	       outpath, (long)st.st_size, width, height, url);
	return 0;
}

static int run_dry_run(const char *ffmpeg, const char *url, const char *outpath,
		       int width, int height)
{
	printf("ai_grab_frame dry-run\n");
	printf("  ffmpeg=%s\n", ffmpeg);
	printf("  url=%s\n", url);
	printf("  out=%s\n", outpath);
	printf("  size=%dx%d\n", width, height);

	if (access(ffmpeg, X_OK) != 0 && strcmp(ffmpeg, "ffmpeg") != 0) {
		fprintf(stderr, "dry-run: ffmpeg not executable: %s\n", ffmpeg);
		return 1;
	}
	printf("  ffmpeg ok (path checked)\n");
	return 0;
}

static void usage(const char *argv0)
{
	printf("usage: %s --dry-run\n", argv0);
	printf("       %s --once [--url RTSP] [--out PATH] [--width W] [--height H]\n",
	       argv0);
	printf("env: AI_RTSP_URL AI_FRAME_PATH AI_FRAME_W AI_FRAME_H FFMPEG\n");
	printf("default: %s -> %s (%dx%d)\n",
	       DEFAULT_URL, DEFAULT_OUT, DEFAULT_W, DEFAULT_H);
}

int main(int argc, char **argv)
{
	const char *ffmpeg, *url, *outpath, *env;
	int width = DEFAULT_W;
	int height = DEFAULT_H;
	int dry = 0;
	int once = 0;
	int i;

	url = getenv("AI_RTSP_URL");
	if (!url || !url[0])
		url = DEFAULT_URL;
	outpath = getenv("AI_FRAME_PATH");
	if (!outpath || !outpath[0])
		outpath = DEFAULT_OUT;
	env = getenv("AI_FRAME_W");
	if (env && env[0])
		width = atoi(env);
	env = getenv("AI_FRAME_H");
	if (env && env[0])
		height = atoi(env);
	ffmpeg = resolve_ffmpeg(getenv("FFMPEG"));

	for (i = 1; i < argc; i++) {
		if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
			usage(argv[0]);
			return 0;
		}
		if (strcmp(argv[i], "--dry-run") == 0) {
			dry = 1;
			continue;
		}
		if (strcmp(argv[i], "--once") == 0) {
			once = 1;
			continue;
		}
		if (strcmp(argv[i], "--url") == 0 && i + 1 < argc) {
			url = argv[++i];
			continue;
		}
		if (strcmp(argv[i], "--out") == 0 && i + 1 < argc) {
			outpath = argv[++i];
			continue;
		}
		if (strcmp(argv[i], "--width") == 0 && i + 1 < argc) {
			width = atoi(argv[++i]);
			continue;
		}
		if (strcmp(argv[i], "--height") == 0 && i + 1 < argc) {
			height = atoi(argv[++i]);
			continue;
		}
		fprintf(stderr, "ai_grab_frame: unknown arg %s\n", argv[i]);
		usage(argv[0]);
		return 1;
	}

	if (width < 16)
		width = DEFAULT_W;
	if (height < 16)
		height = DEFAULT_H;

	if (dry)
		return run_dry_run(ffmpeg, url, outpath, width, height);

	if (!once) {
		usage(argv[0]);
		return 1;
	}

	return grab_once(ffmpeg, url, outpath, width, height) == 0 ? 0 : 1;
}
