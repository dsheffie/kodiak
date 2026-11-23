/* vram.S: the CG14 VRAM (pa 0xfc000000, 64 MB) is memory to kodiak_soc (it goes to
 * the memory bus, not the ARM window).  Stores and loads through the MMU bypass
 * ASI 0x20 (pa[35:32] = 0): words, a byte, a doubleword, the last word of the
 * 8 MB VRAM.  The checker compares every load with the ISS.  Bare metal, ET = 0,
 * ends with `ta 0`.  kodiak_tb -f vram.elf (no board: memory past RAM is memory).
 * Build: clang -E -P -x assembler-with-cpp vram.S -o vram.s &&
 *        sparc64-linux-gnu-as -32 vram.s -o vram.o &&
 *        sparc64-linux-gnu-ld -m elf32_sparc -static -e _start -Ttext=0x400000 -o vram.elf vram.o */
	.text
	.globl _start
_start:
	set	0xfc000000, %l0
	set	0x007ffffc, %l1
	set	0x12345678, %o0
	sta	%o0, [%l0] 0x20
	set	0x9abcdef0, %o1
	add	%l0, 4, %l2
	sta	%o1, [%l2] 0x20
	add	%l0, %l1, %l3
	set	0xcafef00d, %o2
	sta	%o2, [%l3] 0x20
	mov	0x5a, %o3
	add	%l0, 9, %l4
	stba	%o3, [%l4] 0x20
	add	%l0, 16, %l5
	stda	%o0, [%l5] 0x20
	lda	[%l0] 0x20, %g1
	lda	[%l2] 0x20, %g2
	lda	[%l3] 0x20, %g3
	lduba	[%l4] 0x20, %g4
	ldda	[%l5] 0x20, %g6
	lda	[%l0 + %l1] 0x20, %g5
	ta	0
	nop
