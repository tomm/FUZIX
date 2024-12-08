/* 
 * Jeeretro hd/fd/rd driver
 */

#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <devfd.h>

/* In agonlight.s */
extern uint16_t rootfs_image_fread(uint8_t *buf, uint16_t bytes);
extern uint16_t rootfs_image_fwrite(uint8_t *data, uint16_t bytes);
extern uint8_t rootfs_image_fseek(uint32_t position);

static int disk_transfer(bool is_read, uint8_t minor, uint8_t rawflag)
{
    uint8_t st;

#if 0
    uint8_t map = 0;

    if(rawflag == 1) {
        if (d_blkoff(9))
            return -1;
        map = udata.u_page;
#ifdef SWAPDEV
    } else if (rawflag == 2) {		/* Swap device special */
        map = swappage;		        /* Acting on this page */
#endif
    }
#endif /* 0 */

    //kprintf("seek %u. ", 512 * (uint32_t)udata.u_block);
    st = rootfs_image_fseek(512 * (uint32_t)udata.u_block);

    if (st) {
        //kprintf("hd%d: block %d, fseek error %d\n", minor, udata.u_block, st);
    }

    if (is_read) {
        //kprintf("rd %p %u. ", udata.u_dptr, 512 * udata.u_nblock);
        rootfs_image_fread(udata.u_dptr, 512 * udata.u_nblock);
    } else {
        //kprintf("wr buf %p block %d num %u. ", udata.u_dptr, udata.u_block, 512 * udata.u_nblock);
        rootfs_image_fwrite(udata.u_dptr, 512 * udata.u_nblock);
    }

    if (st) {
        kprintf("hd%d: block %d, error %d\n", minor, udata.u_block, st);
        return 0;
    }

    udata.u_block += udata.u_nblock;
    return udata.u_nblock << 9;
}

int fd_open(uint8_t minor, uint16_t flag)
{
    used(flag);
    if(minor >= 4) {
        udata.u_error = ENODEV;
        return -1;
    }
    return 0;
}

int fd_read(uint8_t minor, uint8_t rawflag, uint8_t flag)
{
    used(flag);
    return disk_transfer(true, minor, rawflag);
}

int fd_write(uint8_t minor, uint8_t rawflag, uint8_t flag)
{
    used(flag);
    return disk_transfer(false, minor, rawflag);
}

int hd_open(uint8_t minor, uint16_t flag)
{
    used(flag);
    if(minor >= 64) {
        udata.u_error = ENODEV;
        return -1;
    }
    return 0;
}

int hd_read(uint8_t minor, uint8_t rawflag, uint8_t flag)
{
    used(flag);
    return disk_transfer(true, minor+64, rawflag);
}

int hd_write(uint8_t minor, uint8_t rawflag, uint8_t flag)
{
    used(flag);
    return disk_transfer(false, minor+64, rawflag);
}

int rd_open(uint8_t minor, uint16_t flag)
{
    used(flag);
    if(minor >= 2) {
        udata.u_error = ENODEV;
        return -1;
    }
    return 0;
}

int rd_read(uint8_t minor, uint8_t rawflag, uint8_t flag)
{
    used(flag);
    return disk_transfer(true, minor+128, rawflag);
}

int rd_write(uint8_t minor, uint8_t rawflag, uint8_t flag)
{
    used(flag);
    return disk_transfer(false, minor+128, rawflag);
}
