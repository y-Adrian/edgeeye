#ifndef _DEBRIS_OV5647_REGS_H
#define _DEBRIS_OV5647_REGS_H

#include <linux/types.h>

struct debris_ov5647_reg {
    u16 reg;
    u8  val;
};

extern const struct debris_ov5647_reg debris_ov5647_mode_640x480[];
extern const unsigned int debris_ov5647_mode_640x480_len;

#endif /* _DEBRIS_OV5647_REGS_H */
