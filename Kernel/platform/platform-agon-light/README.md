## A FUZIX target for the Agon Light / Agon Light 2 / Agon Console8

(adapted from the `ezretro` port)

Agon Light has an eZ80F92 processor, and a built in colour terminal with
PS/2 keyboard input and VGA output (implemented with an ESP32).

Agon is configured with a simple 8K fixed common and 56K fixed sized banks,
using the EZ80F92's 8K on-board SRAM for the common area.

We run FUZIX with one application per bank and the memory map currently is:

### Bank 0:

``` text
0000-0080	Vectors
0081-0084	Saved CP/M command info
0100		FUZIX kernel start
????		FUZIX kernel end ~= A000
(big kernels go up to E400 or so!)
no discard area, current kernel easily fits in 56K
End of kernel:	Common >= 0xE000
                uarea
                uarea stack
                interrupt stack
                bank switching code
                user memory access copy
                interrupt vectors and glue
                [Possibly future move the buffers up here to allow for more
                 disk and inode buffer ?]
FFFF		Hard end of kernel room
```

### Bank 1 to Bank n:

``` text
0000		Vector copy
0080		free
0100		Application
DCFF		Application end
DD00-DFFF	uarea stash
```

### Booting

The Kernel/fuzix.bin file is an Agon MOS binary. You can simply put it on
your Agon's SDCard (fat32 filesystem), and execute it from MOS. Fuzix will
expect a fuzix.rootfs filesystem image file in the current (MOS) directory.

### Building userspace

I'm currently unable to build userspace from this repo (based on Fuzix 0.5).
Checking out Fuzix 0.4, and building with:

```
TARGET=easy-z80 make
```

Produces working userspace binaries for Agon.
