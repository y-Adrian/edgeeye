#include "debris.h"

#ifndef _DEBRIS_RING_H
/* ─── 环形缓冲区 ─────────────────────────────────────────────── */
/* 帧槽数与每帧大小均可由 module_param 在 insmod 时配置，
 * 这里仅提供默认值与上下限。实际值保存在 struct debris_ring 中。
 * 注意：采用"留一个空槽"判满，可用容量 = ring_size - 1。
 */
#define DEFAULT_RING_SIZE   4      /* 默认帧槽数（可用容量 3）*/
#define DEFAULT_FRAME_SIZE  128    /* 默认每帧最大字节数 */
#define MIN_RING_SIZE       2      /* 至少 2 槽，保证可用容量 >= 1 */
#define MAX_RING_SIZE       256     /* 帧槽数上限 */
#define MIN_FRAME_SIZE      1
#define MAX_FRAME_SIZE      4096   /* 每帧字节数上限 */

struct debris_frame {
    char   *data;   /* 动态分配，容量 = ring->frame_sz */
    size_t  len;
};

struct debris_ring {
    struct debris_frame *frames;    /* 动态分配的帧数组，长度 = ring->size */
    unsigned int         size;      /* 帧槽数（运行时，= ring_size 参数）*/
    unsigned int         mask;      /* 掩码 */
    unsigned int         frame_sz;  /* 每帧最大字节数（= frame_size 参数）*/
    unsigned int         head;      /* 生产者写入位置 */
    unsigned int         tail;      /* 消费者读取位置 */
};

/* ─── ring_alloc：按运行时参数分配帧缓冲（在 init 中调用，进程上下文）── */
static inline int ring_alloc(struct debris_ring *ring,
                             unsigned int size, unsigned int frame_sz)
{
    unsigned int i;

    /* size & (size - 1) != 0：确保 size 是 2 的幂，便于取模计算 */
    if (size < MIN_RING_SIZE || size > MAX_RING_SIZE || frame_sz < MIN_FRAME_SIZE ||
        frame_sz > MAX_FRAME_SIZE || (size & (size - 1)) != 0) {
        return -EINVAL;
    }

    /* kcalloc：分配并清零帧描述符数组 */
    ring->frames = kcalloc(size, sizeof(*ring->frames), GFP_KERNEL);
    if (!ring->frames)
        return -ENOMEM;

    for (i = 0; i < size; i++) {
        /* kmalloc：为每个帧槽分配 frame_sz 字节的数据缓冲 */
        ring->frames[i].data = kmalloc(frame_sz, GFP_KERNEL);
        if (!ring->frames[i].data) {
            /* 分配失败：回滚已分配的缓冲 */
            while (i--)
                kfree(ring->frames[i].data);
            kfree(ring->frames);
            ring->frames = NULL;
            return -ENOMEM;
        }
    }

    ring->size     = size;
    ring->mask     = size - 1;
    ring->frame_sz = frame_sz;
    ring->head     = 0;
    ring->tail     = 0;
    return 0;
}

/* ─── ring_free：释放帧缓冲（在 exit 中调用）─────────────────── */
static inline void ring_free(struct debris_ring *ring)
{
    unsigned int i;

    if (!ring->frames)
        return;

    /* kfree：逐帧释放数据缓冲，再释放描述符数组 */
    for (i = 0; i < ring->size; i++)
        kfree(ring->frames[i].data);
    kfree(ring->frames);
    ring->frames = NULL;
}

/* ring 辅助函数（调用者须持 slock）*/
static inline int ring_empty(const struct debris_ring *ring)
{
    return ring->head == ring->tail;
}

static inline int ring_full(const struct debris_ring *ring)
{
    return ((ring->head + 1) & ring->mask) == ring->tail;
}

static inline unsigned int ring_count(const struct debris_ring *ring)
{
    return (ring->head - ring->tail + ring->size) & ring->mask;
}

/* ─── ring_push：向 ring head 写入一帧（调用者须持 slock）─────── */
static inline void ring_push(struct debris_ring *ring, const char *data, size_t len)
{
    struct debris_frame *f;

    /* 若满则覆盖最旧帧（丢 tail，适合摄像头流式场景）*/
    if (ring_full(ring)) {
        ring->tail = (ring->tail + 1) & ring->mask;
    }

    f = &ring->frames[ring->head & ring->mask];
    /* memcpy：将数据写入 ring 帧，内核内存操作 */
    len = min(len, (size_t)ring->frame_sz);
    memcpy(f->data, data, len);
    f->len = len;
    ring->head = (ring->head + 1) & ring->mask;
}

/* ─── ring_pop：从 ring tail 读取一帧（调用者须持 slock）─────── */
static inline int ring_pop(struct debris_ring *ring, char *buf, size_t buf_size)
{
    size_t len;
    struct debris_frame *f;

    if (ring_empty(ring))
        return -1;

    f = &ring->frames[ring->tail & ring->mask];
    /* memcpy：将帧数据复制到 buf，内核内存操作 */
    len = min(f->len, buf_size);
    memcpy(buf, f->data, len);
    ring->tail = (ring->tail + 1) & ring->mask;
    return (int)len;
}

#endif /* _DEBRIS_RING_H */