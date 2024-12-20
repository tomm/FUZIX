#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <stdbool.h>
#include <tty.h>
#include <devtty.h>

static char tbuf1[TTYSIZ];

struct  s_queue  ttyinq[NUM_DEV_TTY+1] = {       /* ttyinq[0] is never used */
    {   NULL,    NULL,    NULL,    0,        0,       0    },
    {   tbuf1,   tbuf1,   tbuf1,   TTYSIZ,   0,   TTYSIZ/2 },
};

/* We have no actual controls on the virtual ports */
tcflag_t termios_mask[NUM_DEV_TTY + 1] = {
	0,
        _CSYS
};

static uint8_t ttypoll;

extern char uart0_char_in;
extern void outchar(unsigned char c);
extern char uart0_writeready(void);

/* Write to system console */
void kputchar(char c)
{
    /* handle CRLF */
    if(c=='\n') {
        outchar('\r');
    }
    outchar(c);
}

char tty_writeready(uint8_t minor)
{
    used(minor);
    return uart0_writeready();
}

void tty_putc(uint8_t minor, unsigned char c)
{
    used(minor);
    used(c);

    outchar(c);
}

void tty_sleeping(uint8_t minor)
{
    ttypoll |= 1 << minor;
}

/* Called every timer tick */

static uint8_t tmpReg;

void tty_pollirq(void)
{
    if (uart0_char_in) {
        // Fuzix seems to want 8 for backspace
        if (uart0_char_in == 127) {
            tty_inproc(1, 8);
        } else if (uart0_char_in != 17 /* ignore XON */) {
            tty_inproc(1, uart0_char_in);
        }
        uart0_char_in = 0;
    }
}    

void tty_setup(uint8_t minor, uint8_t flags)
{
    used(minor);
    used(flags);
}

/* For the moment */
int tty_carrier(uint8_t minor)
{
    used(minor);
    return 1;
}

void tty_data_consumed(uint8_t minor)
{
    used(minor);
}
