.data
last_tail_ptr:
        .word 0

.globl intr_handler
	.align  2
	.type intr_handler, @function
	.section .exception

intr_handler:
	# TODO: Please add your own interrupt handler for DMA engine 
# get ctrl_stat
	li	$k0, 0x60020014
	lw	$k1, 0($k0)
	li	$k0, 0x7fffffff
	and	$k1, $k0, $k1	# clear INTR
	li	$k0, 0x60020014
	sw	$k1, 0($k0)
# decrease dma_buf_stat
	la	$k0, last_tail_ptr
	lw	$k0, 0($k0)	# $k0 := last_tail_ptr
LT:
	li	$k1, 0x60020008
	lw	$k1, 0($k1)	# $k1 := tail_ptr

	sltu	$k1, $k0, $k1
	beq	$k1, $0, RT	# if $k0 >= $k1 then goto RT

	la	$k1, dma_buf_stat
	lw	$k0, 0($k1)	# $k0 := dma_buf_stat
	addiu	$k0, $k0, -1
	sw	$k0, 0($k1)	# dma_buf_stat := $k0 - 1

	li	$k1, 0x60020010
	lw	$k1, 0($k1)	# $k1 := dma_size
	la	$k0, last_tail_ptr
	lw	$k0, 0($k0)	# $k0 := last_tail_ptr
	addu	$k0, $k0, $k1	# $k0 += $k1
	la	$k1, last_tail_ptr
	sw	$k0, 0($k1)	# last_tail_ptr := $k0
	j	LT
RT:
# return
	eret
