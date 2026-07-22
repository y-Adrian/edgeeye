/* ai_event_log.c — EdgeEye AI 事件本地日志（步骤 2：无模型）
 *
 * 测试接口：--dry-run / --inject person；环境变量 AI_LOG_DIR
 * 测试场景：创建日志目录；追加一条 person NDJSON；再读回校验
 *
 * 用法：
 *   ./ai_event_log --dry-run
 *   ./ai_event_log --inject person [--score 0.92] [--cam cam0]
 *   AI_LOG_DIR=/mnt/sd/events ./ai_event_log --inject person
 *
 * 日志：${AI_LOG_DIR}/events.ndjson（每行一条 JSON）
 */
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

static const char *default_log_dir(void)
{
	/* access：检查 SD 是否可写 */
	if (access("/mnt/sd", W_OK) == 0)
		return "/mnt/sd/events";
	return "/mnt/data/events";
}

static int ensure_dir(const char *path)
{
	struct stat st;

	/* stat：判断路径是否已是目录 */
	if (stat(path, &st) == 0) {
		if (S_ISDIR(st.st_mode))
			return 0;
		fprintf(stderr, "ai_event_log: not a dir: %s\n", path);
		return -1;
	}
	/* mkdir：创建事件日志目录 */
	if (mkdir(path, 0755) == 0)
		return 0;
	if (errno == EEXIST)
		return 0;
	fprintf(stderr, "ai_event_log: mkdir %s: %s\n", path, strerror(errno));
	return -1;
}

static int append_event(const char *dir, const char *cls, double score,
			const char *source, const char *cam)
{
	char path[512];
	FILE *fp;
	time_t now;

	if (ensure_dir(dir) != 0)
		return -1;

	snprintf(path, sizeof(path), "%s/events.ndjson", dir);
	/* fopen：追加写入 NDJSON 事件 */
	fp = fopen(path, "a");
	if (!fp) {
		fprintf(stderr, "ai_event_log: open %s: %s\n", path, strerror(errno));
		return -1;
	}

	now = time(NULL);
	/* fprintf：写入一行事件；fflush 保证立刻落盘 */
	fprintf(fp,
		"{\"ts\":%ld,\"class\":\"%s\",\"score\":%.4f,\"source\":\"%s\",\"cam\":\"%s\"}\n",
		(long)now, cls, score, source, cam);
	fflush(fp);
	fclose(fp);

	printf("ai_event_log: wrote %s class=%s score=%.4f source=%s cam=%s\n",
	       path, cls, score, source, cam);
	return 0;
}

static int run_dry_run(const char *dir)
{
	char path[512];
	struct stat st;

	printf("ai_event_log dry-run\n");
	printf("  log_dir=%s\n", dir);

	if (ensure_dir(dir) != 0)
		return 1;
	printf("  log_dir ok\n");

	snprintf(path, sizeof(path), "%s/events.ndjson", dir);
	if (stat(path, &st) == 0)
		printf("  events.ndjson exists size=%ld\n", (long)st.st_size);
	else
		printf("  events.ndjson not yet (will create on inject)\n");

	printf("  classes=person (only)\n");
	return 0;
}

static void usage(const char *argv0)
{
	printf("usage: %s --dry-run\n", argv0);
	printf("       %s --inject person [--score 0.9] [--cam cam0] [--log-dir DIR]\n",
	       argv0);
	printf("env: AI_LOG_DIR (default /mnt/sd/events or /mnt/data/events)\n");
}

int main(int argc, char **argv)
{
	const char *dir;
	const char *cls = NULL;
	const char *cam = "cam0";
	const char *source = "inject";
	double score = 1.0;
	int dry = 0;
	int inject = 0;
	int i;

	dir = getenv("AI_LOG_DIR");
	if (!dir || !dir[0])
		dir = default_log_dir();

	for (i = 1; i < argc; i++) {
		if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
			usage(argv[0]);
			return 0;
		}
		if (strcmp(argv[i], "--dry-run") == 0) {
			dry = 1;
			continue;
		}
		if (strcmp(argv[i], "--inject") == 0) {
			inject = 1;
			if (i + 1 < argc && argv[i + 1][0] != '-') {
				cls = argv[++i];
			} else {
				cls = "person";
			}
			continue;
		}
		if (strcmp(argv[i], "--score") == 0 && i + 1 < argc) {
			score = atof(argv[++i]);
			continue;
		}
		if (strcmp(argv[i], "--cam") == 0 && i + 1 < argc) {
			cam = argv[++i];
			continue;
		}
		if (strcmp(argv[i], "--log-dir") == 0 && i + 1 < argc) {
			dir = argv[++i];
			continue;
		}
		if (strcmp(argv[i], "--source") == 0 && i + 1 < argc) {
			source = argv[++i];
			continue;
		}
		fprintf(stderr, "ai_event_log: unknown arg %s\n", argv[i]);
		usage(argv[0]);
		return 1;
	}

	if (dry)
		return run_dry_run(dir);

	if (!inject) {
		usage(argv[0]);
		return 1;
	}

	if (!cls)
		cls = "person";
	/* 步骤 2/4：产品只做人检测 */
	if (strcmp(cls, "person") != 0) {
		fprintf(stderr, "ai_event_log: only class 'person' supported now\n");
		return 1;
	}
	if (score < 0.0)
		score = 0.0;
	if (score > 1.0)
		score = 1.0;

	return append_event(dir, cls, score, source, cam) == 0 ? 0 : 1;
}
