/* ai_grab_frame.c — EdgeEye AI 取帧（VPSS 直取或 RTSP → 低分辨率 JPEG）
 *
 * 测试接口：--dry-run / --once；环境变量 AI_RTSP_URL / AI_FRAME_PATH / FFMPEG
 * 测试场景：cam0 RTSP 就绪时抓一帧 scale 后的 JPEG，供步骤 4 检测使用
 *
 * 用法：
 *   ./ai_grab_frame --dry-run
 *   ./ai_grab_frame --once --source vpss
 *   ./ai_grab_frame --once --source rtsp
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
#define DEFAULT_SOURCE "vpss"
#define VPSS_REQUEST "/tmp/edgeeye_ai_frame.request"
#define VPSS_RAW     "/tmp/edgeeye_ai_frame.nv12"
#define VPSS_META    "/tmp/edgeeye_ai_frame.meta"

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

static int request_vpss_frame(int *source_width, int *source_height)
{
	FILE *fp;
	struct stat raw_st, meta_st;
	int attempt;

	/* unlink：移除旧帧，确保后续观察到的是本次请求结果。 */
	unlink(VPSS_RAW);
	unlink(VPSS_META);
	/* fopen：创建请求文件，由 edgeeye_cam 的导帧线程消费。 */
	fp = fopen(VPSS_REQUEST, "w");
	if (!fp) {
		fprintf(stderr, "ai_grab_frame: create request failed: %s\n",
			strerror(errno));
		return -1;
	}
	/* fprintf：写入可读标记，便于板上排查遗留请求。 */
	fprintf(fp, "capture\n");
	/* fclose：发布完整请求并释放文件描述符。 */
	if (fclose(fp) != 0)
		return -1;

	for (attempt = 0; attempt < 120; attempt++) {
		/* stat：等待 edgeeye_cam 原子发布 raw 与尺寸元数据。 */
		if (stat(VPSS_RAW, &raw_st) == 0 && raw_st.st_size > 64 &&
		    stat(VPSS_META, &meta_st) == 0 && meta_st.st_size > 0)
			break;
		/* usleep：每 50ms 检查一次，最长等待约 6 秒。 */
		usleep(50000);
	}
	if (attempt == 120) {
		fprintf(stderr,
			"ai_grab_frame: VPSS request timeout (edgeeye_cam needs --ai-direct)\n");
		return -1;
	}

	/* fopen：读取导出帧的宽高。 */
	fp = fopen(VPSS_META, "r");
	if (!fp)
		return -1;
	/* fscanf：解析“width height”元数据。 */
	if (fscanf(fp, "%d %d", source_width, source_height) != 2) {
		/* fclose：关闭格式错误的元数据文件。 */
		fclose(fp);
		return -1;
	}
	/* fclose：关闭已读取的元数据文件。 */
	fclose(fp);
	return 0;
}

static int grab_vpss_once(const char *ffmpeg, const char *outpath,
			  int width, int height)
{
	char cmd[1400];
	struct stat st;
	int source_width = 0;
	int source_height = 0;

	if (request_vpss_frame(&source_width, &source_height) != 0)
		return -1;

	/*
	 * system/ffmpeg：把 VPSS 导出的 NV12 直接缩放编码为 JPEG；
	 * 不建立第二个 RTSP 客户端，也不再解码 H.264。
	 */
	snprintf(cmd, sizeof(cmd),
		 "%s -y -loglevel error -f rawvideo -pixel_format nv12 "
		 "-video_size %dx%d -i '%s' -vf scale=%d:%d "
		 "-frames:v 1 -q:v 5 -f image2 '%s' 2>/dev/null",
		 ffmpeg, source_width, source_height, VPSS_RAW,
		 width, height, outpath);
	if (run_cmd(cmd) != 0) {
		fprintf(stderr, "ai_grab_frame: VPSS raw conversion failed\n");
		return -1;
	}
	/* stat：确认输出 JPEG 已生成且非空。 */
	if (stat(outpath, &st) != 0 || st.st_size < 64) {
		fprintf(stderr, "ai_grab_frame: bad output %s\n", outpath);
		return -1;
	}

	printf("ai_grab_frame: ok path=%s bytes=%ld size=%dx%d source=vpss raw=%dx%d\n",
	       outpath, (long)st.st_size, width, height,
	       source_width, source_height);
	return 0;
}

static int run_dry_run(const char *ffmpeg, const char *source, const char *url,
		       const char *outpath, int width, int height)
{
	printf("ai_grab_frame dry-run\n");
	printf("  ffmpeg=%s\n", ffmpeg);
	printf("  source=%s\n", source);
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
	printf("       %s --once [--source vpss|rtsp] [--url RTSP] [--out PATH] "
	       "[--width W] [--height H]\n",
	       argv0);
	printf("env: AI_FRAME_SOURCE AI_RTSP_URL AI_FRAME_PATH AI_FRAME_W AI_FRAME_H FFMPEG\n");
	printf("default: source=%s %s -> %s (%dx%d)\n",
	       DEFAULT_SOURCE, DEFAULT_URL, DEFAULT_OUT, DEFAULT_W, DEFAULT_H);
}

int main(int argc, char **argv)
{
	const char *ffmpeg, *source, *url, *outpath, *env;
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
	source = getenv("AI_FRAME_SOURCE");
	if (!source || !source[0])
		source = DEFAULT_SOURCE;
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
		if (strcmp(argv[i], "--source") == 0 && i + 1 < argc) {
			source = argv[++i];
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
	if (strcmp(source, "vpss") != 0 && strcmp(source, "rtsp") != 0) {
		fprintf(stderr, "ai_grab_frame: invalid source %s (use vpss|rtsp)\n",
			source);
		return 1;
	}

	if (dry)
		return run_dry_run(ffmpeg, source, url, outpath, width, height);

	if (!once) {
		usage(argv[0]);
		return 1;
	}

	if (strcmp(source, "vpss") == 0)
		return grab_vpss_once(ffmpeg, outpath, width, height) == 0 ? 0 : 1;
	return grab_once(ffmpeg, url, outpath, width, height) == 0 ? 0 : 1;
}
