#include <kernel.h>
#include <timer.h>
#include <kdata.h>
#include <printf.h>
#include <devtty.h>

uaddr_t ramtop = PROGTOP;

// in agonlight.s
extern uint8_t root_image_handle;

void pagemap_init(void)
{
    int i;
    for (i = 1; i <= MAX_MAPS; i++)
        pagemap_add(i);
}

void plt_idle(void)
{
}

void plt_interrupt(void)
{
    tty_pollirq();
    timer_interrupt();
}

/* Nothing to do for the map of init */
void map_init(void)
{
}

uint8_t plt_param(char *p)
{
    used(p);
    return 0;
}

void main()
{
    if (root_image_handle == 0) {
        kprintf("Could not open ./fuzix.rootfs image.\n");
        return;
    }
    fuzix_main();
}
