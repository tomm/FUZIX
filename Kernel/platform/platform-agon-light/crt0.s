; 2013-12-18 William R Sowerbutts

        .module crt0

        ; Ordering of segments for the linker.
        ; WRS: Note we list all our segments here, even though
        ; we don't use them all, because their ordering is set
        ; when they are first seen.
        .area _CODE
        .area _CODE2
        .area _CONST
        .area _INITIALIZED
        .area _DATA
        .area _BSEG
        .area _BSS
        .area _HEAP
        ; note that areas below here may be overwritten by the heap at runtime, so
        ; put initialisation stuff in here
        .area _INITIALIZER
        .area _GSINIT
        .area _GSFINAL
	.area _DISCARD
        .area _COMMONMEM
        .area _COMMONDATA

        ; imported symbols
        .globl _main
        .globl init_hardware
        .globl open_disk_images
        .globl s__INITIALIZER
        .globl s__COMMONMEM
        .globl l__COMMONMEM
        .globl s__COMMONDATA
        .globl l__COMMONDATA
        .globl s__DISCARD
        .globl l__DISCARD
        .globl s__DATA
        .globl l__DATA
        .globl kstack_top

; ez80 size prefixes
LIS			    .equ 0x49

        ; startup code
        .area _CODE
; 0x0
init:
		jp init2
		.ds 61
		.ascii "MOS"
		.db 0, 0
		.ds 187
		
; 0x100
init2:
        di

		; Map common RAM (8K on-chip SRAM) to bank 4 (e000 - ffff)
		; Kernel stack resides there, so we need this before
		; we use the stack!
        ld a, #4
        ; out0 (RAM_BANK),a		(set SRAM to bank 4)
        .db 0xED,0x39,0xB5

        ld sp, #kstack_top

	; move the common memory where it belongs    
	ld hl, #s__DATA
	ld de, #s__COMMONMEM
	ld bc, #l__COMMONMEM
	ldir
	ld de, #s__COMMONDATA
	ld bc, #l__COMMONDATA
	ldir
	; and the discard
	ld de, #s__DISCARD
	ld bc, #l__DISCARD
	ldir
	; then zero the data area
	ld hl, #s__DATA
	ld de, #s__DATA + 1
	ld bc, #l__DATA - 1
	ld (hl), #0
	ldir

        ; Hardware setup
        call init_hardware

		call open_disk_images

        ; Call the C main routine
        call _main
    
        ; main shouldn't return, but if it does...
        di
stop:   halt
        jr stop

