; This is a mix of code taken from FUZIX's z80pak.s and sbcv2.s -jcw
; For use with the EZ-Retro v2 board, see https://docs.jeelabs.org/projects/ezr/
;
; Original & modified code follows, in messy / not-cleaned-up state for now.
;
;	EZ Retro v2 support
;


            .module agonlight

	    .ez80
	    .adl 0

            ; exported symbols
            .globl init_hardware
			.globl open_disk_images
            .globl _program_vectors
			.globl _root_image_handle
			.globl _rootfs_image_fseek
			.globl _rootfs_image_fread
			.globl _rootfs_image_fwrite
			.globl _uart0_char_in
	    .globl plt_interrupt_all

	    .globl map_kernel
	    .globl map_kernel_restore
	    .globl map_kernel_di
	    .globl map_proc
	    .globl map_proc_di
	    .globl map_proc_always
	    .globl map_proc_always_di
	    .globl map_proc_a
	    .globl map_save_kernel
	    .globl map_restore

	    .globl _int_disabled

	    .globl _plt_reboot

            ; exported debugging tools
            .globl _plt_monitor
            .globl outchar
            .globl _outchar

            ; imported symbols
            .globl _ramsize
            .globl _procmem
			.globl _timer_interrupt

	    .globl unix_syscall_entry
            .globl null_handler
	    .globl nmi_handler
            .globl interrupt_handler

            .include "kernel.def"
            .include "../../cpu-z80/kernel-z80.def"

; -----------------------------------------------------------------------------
; COMMON MEMORY BANK (0xE000 upwards)
; -----------------------------------------------------------------------------
            .area _COMMONMEM

_plt_monitor:
_plt_reboot:
		di
		; exit VDP terminal mode
		ld a,#27
		call outchar
		ld a,#'_'
		call outchar
		ld a,#'#'
		call outchar
		ld a,#'Q'
		call outchar
		ld a,#'!'
		call outchar
		ld a,#'$'
		call outchar
		.db 0x5b	; jp.lil 0
		jp 0
		.db 0

plt_interrupt_all:
	    ret

; -----------------------------------------------------------------------------
; KERNEL MEMORY BANK (below 0xC000, only accessible when the kernel is mapped)
; -----------------------------------------------------------------------------
            .area _CODE

TMR1_CTL	.equ	0x83
TMR1_DR_L	.equ	0x84
TMR1_DR_H	.equ	0x85

init_hardware:
            ; set system RAM size
			; 512k - 64k (used by agon MOS) = 448K
            ld hl, #448
            ld (_ramsize), hl
            ld hl, #(448-64)		; 64K for kernel
            ld (_procmem), hl

            ; set up interrupt vectors for the kernel
            ld hl, #0
            push hl
            call _program_vectors
            pop hl

			; turn off vblank interrupt
			;ld a,#0xff
			;out0 (0x9b),a		; PB_DDR
			;xor a
			;out0 (0x9c),a		; PB_ALT1
			;out0 (0x9d),a		; PB_ALT2

			; set up timer interrupt handler (using ez80f92 PRT timer 0)
			ld hl, #timer1_interrupt
			ld a, #4				; in segment 0x40000
			call copy_a_top_hl24	; MOS requires 24-bit interrupt handler pointer
			ld e, #0xc		; timer1 interrupt number
			ld a, #0x14 	; mos_api_setintvector
			.db #0x49   ; rst.lis (lis suffix)
			rst #8

			; set up timer1 (18.432MHz / 256 divider * 720 reload counter = 100Hz)
			xor a
			out0 (0x92),a
			ld a,#0x5f
			ld hl,#720
			out0 (TMR1_CTL),a
			out0 (TMR1_DR_L),l
			out0 (TMR1_DR_H),h

			; set up keyboard event handler
			ld hl, #uart0_rx_interrupt
			ld a, #4				; in segment 0x40000
			call copy_a_top_hl24
			ld e, #0x18		; interrupt number
			ld a, #0x14 	; mos_api_setintvector
			.db #0x49   ; rst.lis (lis suffix)
			rst #8

			xor a
			ld (_uart0_char_in), a

            ret
	
; set top byte of 24-bit HL to A
copy_a_top_hl24:
			.db #0x5b   ; .lil suffix
			push hl
			.db #0x5b   ; .lil suffix
			ld hl, #2
			.db 0
			.db #0x5b   ; .lil suffix
			add hl, sp
			.db #0x5b   ; .lil suffix
			ld (hl), a
			.db #0x5b   ; .lil suffix
			pop hl
			ret

_rootfs_image_fseek:
			; (uint32_t position) -> uint8_t
			push ix
			ld ix,#0
			add ix,sp

			push hl
			push de
			push bc

			ld hl,4(ix)  ; low 2 bytes of position
			ld de,6(ix)  ; high 2 bytes of position

			; mos_api_flseek wants 32-bit position in E:HL24
			ld a,e
			call copy_a_top_hl24
			ld e,d
			ld d,#0

			ld a,(_root_image_handle)
			ld c,a
			ld a,#0x1c		; mos_api_flseek
			.db #0x49   ; rst.lis (lis suffix)
			rst 8
			
			;.db #0x5b   ; .lil suffix

			pop hl
			pop de
			pop bc
			pop ix
			ret

_rootfs_image_fread:
			; params (uint8_t *buf, uint16_t bytes) -> uint16_t bytes read
			push ix
			ld ix,#0
			add ix,sp
			push bc
			push de
			push hl

			ld a,(_root_image_handle)
			ld c,a
			ld hl,4(ix)
			.db 0xed,0x6e  ; ld a,mb
			call copy_a_top_hl24     ; set top byte HL24 to kernel segment (4)
			; ld.lil de,#0
			.db #0x5b   ; .lil suffix
			ld de,#0
			.db 0
			ld de,6(ix)				; bytes to read
			ld a,#0x1a				; mos_api_fread
			.db #0x49   ; rst.lis (lis suffix)
			rst 8

			pop hl
			ld h,d	; number of bytes read in hl
			ld l,e
			pop de
			pop bc
			pop ix
			ret

_rootfs_image_fwrite:
			; params (uint8_t *data, uint16_t bytes) -> uint16_t bytes written
			push ix
			ld ix,#0
			add ix,sp
			push bc
			push de
			push hl

			ld a,(_root_image_handle)
			ld c,a
			ld hl,4(ix)
			.db 0xed,0x6e  ; ld a,mb
			call copy_a_top_hl24     ; set top byte HL24 to kernel segment (4)
			; ld.lil de,#0
			.db #0x5b   ; .lil suffix
			ld de,#0
			.db 0
			ld de,6(ix)				; bytes to read
			ld a,#0x1b				; mos_api_fwrite
			.db #0x49   ; rst.lis (lis suffix)
			rst 8

			pop hl
			ld h,d	; number of bytes written in hl
			ld l,e
			pop de
			pop bc
			pop ix
			ret

open_disk_images:
			push hl
			push bc
			; Opens root (and swap eventually) disk images on the
			; MOS BIOS's FAT filesystem
			ld hl, #root_image_filename
			ld c, #3 	; read-write
			ld a, #10	; mos_api_fopen
			.db #0x49   ; rst.lis (lis suffix)
			rst 8
			ld (_root_image_handle), a
			pop bc
			pop hl
			ret

_root_image_handle: .ds 1
root_image_filename: .asciz "fuzix.rootfs"

; this code runs in 24-bit ADL mode and must be placed outside SRAM
; FIXME this doesn't handle interrupts in ADL mode, avoid interrupts for now
seladl:     
			; Hmm. Perhaps 'di' necessary since bank switch is non-atomic (has 2 operations)
			di
			add a,#4			; Default Agon memory map -> RAM starts at segment 0x40000
			out0 (0xb5),a		; (move SRAM to selected bank)
            .db 0xED,0x6D		; ld  mb,a (set MBASE to selected bank)
			sub a,#4
            ; jp.sis selret             (exit ADL mode)
            .db 0x40,0xC3 
            .dw selret

;------------------------------------------------------------------------------
; COMMON MEMORY PROCEDURES FOLLOW

            .area _COMMONMEM

_int_disabled:
	    .byte 1
_uart0_char_in:
		.byte 1

; arrive here in ADL mode (24-bit mode)
uart0_rx_interrupt:
		di
		push af

		; borrowed from Agon MOS UART0_serial_RX
		in0		a,(0xc5)	; Get the line status register
		and a, #1		    ; Check for characters in buffer
		jr nz, .read_char
		xor a
		jr .done
.read_char:
		; call into Z80-mode (so we can access common area)
		.db 0x40	; call.sis
		call uart0_rx_z80
.done:
		pop af
		ei
		.db 0x5b	; reti.lil
		reti
uart0_rx_z80:
		in0	a,(0xc0)	; Read the character from the UART receive buffer
		ld (_uart0_char_in), a
		.db #0x49   ; .lis suffix
		ret

; arrive here in ADL mode (24-bit mode)
timer1_interrupt:
		di
		push af

		; Acknowledge timer1 interrupt
		in0 a,(TMR1_CTL)

		push bc
		push de
		push hl
		push ix
		push iy

		; call into Z80-mode
		.db 0x40	; call.sis
		call timer1_interrupt_z80

		pop iy
		pop ix
		pop hl
		pop de
		pop bc
		pop af
		ei
		.db 0x5b	; reti.lil
		reti

timer1_interrupt_z80:
		call interrupt_handler
		.db #0x49   ; .lis suffix
		ret

_program_vectors:
            ; we are called, with interrupts disabled, by both newproc() and crt0
	    ; will exit with interrupts off
            di ; just to be sure
            pop de ; temporarily store return address
            pop hl ; function argument -- base page number
            push hl ; put stack back as it was
            push de

	    call map_proc

            ; write zeroes across all vectors
            ld hl, #0
            ld de, #1
            ld bc, #0x007f ; program first 0x80 bytes only
            ld (hl), #0x00
            ldir

            ; rst.lil 0x38, to jump to MOS crash handler
			ld a, #0x5b
            ld (0x0038), a
			ld a, #0xff
            ld (0x0039), a

            ; set restart vector for FUZIX system calls
            ld a, #0xC3 ; JP instruction
            ld (0x0030), a   ;  (rst 30h is unix function call vector)
            ld hl, #unix_syscall_entry
            ld (0x0031), hl

            ld (0x0000), a   
            ld hl, #null_handler   ;   to Our Trap Handler
            ld (0x0001), hl

            ld (0x0066), a  ; Set vector for NMI
            ld hl, #nmi_handler
            ld (0x0067), hl

	    ; and fall into map_kernel

map_kernel:
map_kernel_di:
map_kernel_restore:
	    push af
	    xor a
	    call selmem
	    pop af
            ret

map_proc:
map_proc_di:
	    ld a, h
	    or l
	    jr z, map_kernel
	    ld a, (hl)
map_proc_a:
; the actual bank-switching code is in low memory, since SRAM is being moved
selmem:     ; jp.lil {4,seladl}		(enter ADL mode)
            .db 0x5B,0xC3
            .dw seladl
            .db 0x04
selret:     ret ; control returns here once SRAM and MBASE have been adjusted

map_proc_always:
map_proc_always_di:
	    push af
	    ld a, (_udata + U_DATA__U_PAGE)
	    call selmem
	    pop af
	    ret

map_save_kernel:
	    push af
	    .db 0xed,0x6e  ; ld a,mb
	    sub a,#4
	    ld (mapsave), a
	    xor a
	    call selmem
	    pop af
	    ret	    

map_restore:
	    push af
	    ld a, (mapsave)
	    call selmem
	    pop af
	    ret	    

mapsave:    .db 0

; outchar: print the char in A
; Note that devtty.c contains the routine usually used.
outchar:
_outchar:
		push af
wait_uart0_cts:
		in0 a,(0xa2)
		tst a,#8
		jr nz,wait_uart0_cts
uart0_not_ready:
		in0 a,(0xc5)  ; UART0_LSR
		and #0x60      ; either TEMT or THRE (fifo empty, but transmit shift register can be active)
		jr z, uart0_not_ready
		; write to uart0
		pop af
		out0 (0xc0), a
		ret
