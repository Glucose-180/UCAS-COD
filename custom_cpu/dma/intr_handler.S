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
	la	$k0, dma_buf_stat
	lw	$k1, 0($k0)
	addiu	$k1, $k1, -1
	sw	$k1, 0($k0)
# return
	eret
