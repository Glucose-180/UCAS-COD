
#ifndef __DMA_H_
#define __DMA_H_

#ifdef DMA_SIMU
#define BUF_SIZE		(1 << 12)
#else
#define BUF_SIZE		(1 << 20)
#endif

#ifdef DMA_SIMU
#define DMA_SIZE		(1 << 9)
#else
#define DMA_SIZE		(1 << 12)
#endif

//offset of DMA engine MMIO registers
#define DMA_SRC_BASE	0x00
#define DMA_DEST_BASE	0x04
#define DMA_TAIL_PTR	0x08
#define DMA_HEAD_PTR	0x0c
#define DMA_SIZE_REG	0x10
#define DMA_CTRL_STAT	0x14

//bit mask of DMA ctrl_stat register
#define DMA_EN			(1 << 0)
#define DMA_INTR		(1 << 31)

//base address of DMA MMIO register set
volatile unsigned int *dma_mmio = (void *)(0x60020000);

//source and destination buffer
unsigned char src_buf[BUF_SIZE];
unsigned char dest_buf[BUF_SIZE];

#endif

