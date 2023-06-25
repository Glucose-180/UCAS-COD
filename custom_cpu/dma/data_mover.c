#include "dma.h"
#include "printf.h"
#include "trap.h"

void dma_setup()
{
	unsigned int reg_val;

	//set base address of source and destination buffer respectively
	*(dma_mmio + (DMA_SRC_BASE >> 2)) = (unsigned int)src_buf;
	*(dma_mmio + (DMA_DEST_BASE >> 2)) = (unsigned int)dest_buf; 

	//set size (number of bytes) of DMA transferring
	*(dma_mmio + (DMA_SIZE_REG >> 2)) = DMA_SIZE;

	//clear DMA work queue
	*(dma_mmio + (DMA_TAIL_PTR >> 2)) = 0;
	*(dma_mmio + (DMA_HEAD_PTR >> 2)) = 0;

	//enable DMA engine
	reg_val = *(dma_mmio + (DMA_CTRL_STAT >> 2));
	reg_val |= DMA_EN;
	*(dma_mmio + (DMA_CTRL_STAT >> 2)) = reg_val;
}

void generate_data(unsigned int *buf)
{
	unsigned int *addr = buf;
	
	for(int i = 0; i < (DMA_SIZE / sizeof(int)); i++)
		*(addr + i) = i;
}

void memcpy()
{
	unsigned int *src = (unsigned int *)src_buf;
	unsigned int *dest = (unsigned int *)dest_buf;

	for(int i = 0; i < (BUF_SIZE / sizeof(int)); i++)
		*dest++ = *src++;
}

void setup_buf()
{
	volatile extern int dma_buf_stat;

	int sub_buf_num = (BUF_SIZE / DMA_SIZE);

	unsigned char *buf = src_buf;

#ifdef USE_DMA
	unsigned int reg_val;
#endif

	dma_buf_stat = 0;
	
	for(int i = 0; i < sub_buf_num; i++)
	{
		generate_data((unsigned int *)buf);

		//move buffer pointer to next sub region
		buf += DMA_SIZE;
		dma_buf_stat++;

#ifdef USE_DMA
		//refresh head ptr in DMA engine
		reg_val = *(dma_mmio + (DMA_HEAD_PTR >> 2));
		reg_val += DMA_SIZE;
		*(dma_mmio + (DMA_HEAD_PTR >> 2)) = reg_val;
#endif
	}

#ifdef USE_DMA
	//waiting for all sub-region are processed by DMA engine
	while(dma_buf_stat);
#else
	memcpy();
#endif
}

int main()
{
#ifdef USE_DMA
	printf("Prepare DMA engine\n");
	
	//setup DMA engine
	dma_setup();
#endif

	//start buffer writing
	printf("Prepare SW data mover\n");
	setup_buf();

	printf("benchmark finished\n");
	return 0;
}

