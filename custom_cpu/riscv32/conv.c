#include "printf.h"
#include "trap.h"
#include "mul.h"
#include "div.h"
#include "perf_cnt.h"

#define FRAC_BIT 10

#define RD_ADDR 135106448
#define RD_SIZE_D0 1
#define RD_SIZE_D1 1
#define RD_SIZE_D2 28
#define RD_SIZE_D3 28

#define WEIGHT_ADDR 134217728
#define WEIGHT_SIZE_D0 20
#define WEIGHT_SIZE_D1 1
#define WEIGHT_SIZE_D2 5
#define WEIGHT_SIZE_D3 5

#define WR_ADDR 135108240
#define WR_SIZE_D0 1
#define WR_SIZE_D1 20
#define WR_SIZE_D2 12
#define WR_SIZE_D3 12

#define KERN_ATTR_CONV_PAD 0
#define KERN_ATTR_CONV_STRIDE 1
#define KERN_ATTR_POOL_PAD 0
#define KERN_ATTR_POOL_KERN_SIZE 2
#define KERN_ATTR_POOL_STRIDE 2

//MMIO register address of DNN accelerator
#define GPIO_START_ADDR    0x60030000
#define GPIO_DONE_ADDR     0x60030008

//min for signed short int
#define SHT_MIN_G (0x8000)

#define CBUF_H WR_SIZE_D2 * KERN_ATTR_POOL_KERN_SIZE
#define CBUF_W WR_SIZE_D3 * KERN_ATTR_POOL_KERN_SIZE

//static int conv_buf[WR_SIZE_D1][CBUF_H][CBUF_W];
/* NOTE: there has 2*FRAC_BIT frac bits */

static const unsigned WD231 = WEIGHT_SIZE_D2 * WEIGHT_SIZE_D3 + 1;
static const unsigned RD23 = RD_SIZE_D2 * RD_SIZE_D3;
static const unsigned OD23 = WR_SIZE_D2 * WR_SIZE_D3;
static const unsigned Chw = CBUF_H * CBUF_W;


struct size_vec4
{
	unsigned d0;
	unsigned d1;
	unsigned d2;
	unsigned d3;
};

struct mem_addr
{
	unsigned rd_addr;
	unsigned weight_addr;
	unsigned wr_addr;
};

int mul(int a, int b)
{
#ifndef USE_MUL
	int ans = mul_ll(a, b);
#else
	int ans = a * b;
#endif
	return ans;
}

struct mem_addr addr = {RD_ADDR, WEIGHT_ADDR, WR_ADDR};
struct size_vec4 rd_size = {RD_SIZE_D0, RD_SIZE_D1, RD_SIZE_D2, RD_SIZE_D3};
struct size_vec4 wr_size = {WR_SIZE_D0, WR_SIZE_D1, WR_SIZE_D2, WR_SIZE_D3};
struct size_vec4 weight_size = {WEIGHT_SIZE_D0, WEIGHT_SIZE_D1, WEIGHT_SIZE_D2, WEIGHT_SIZE_D3};

struct size_vec4 conv_size;

extern char _binary_data_result_bin_start[];
extern char _binary_data_result_bin_size[];

void convolution()
{
	short *in = (short *)addr.rd_addr;
	short *weight = (short *)addr.weight_addr;
	short *out = (short *)addr.wr_addr;

	unsigned output_offset = 0;
	unsigned input_offset = 0;

	unsigned input_fm_w = rd_size.d3;
	unsigned input_fm_h = rd_size.d2;

	unsigned pad = KERN_ATTR_CONV_PAD;
	unsigned pad_len = pad << 1;

	unsigned conv_out_w = rd_size.d3 - weight_size.d3 + pad_len;
	unsigned conv_out_h = rd_size.d2 - weight_size.d2 + pad_len;

	unsigned stride = KERN_ATTR_CONV_STRIDE;

	signed int och, ich, ox, oy, wx, wy;

	conv_out_w = div(conv_out_w, stride);
	conv_out_h = div(conv_out_h, stride);

	conv_out_w++;
	conv_out_h++;

	conv_size.d0 = wr_size.d0;
	conv_size.d1 = wr_size.d1;
	conv_size.d2 = conv_out_h;
	conv_size.d3 = conv_out_w;

	//TODO: Please add your implementation here
	for (och = 0; och < conv_size.d1; ++och)
	{	/* output channel: 20 */
		for (ich = 0; ich < conv_size.d0; ++ich)
		{	/* input channel: 1 */
			for (oy = 0; oy < conv_size.d2; ++oy)
				for (ox = 0; ox < conv_size.d3; ++ox)
				{
					int temp;
					/* 32-bit intermediate */
					if (ich == 0)	/* bias */
						temp = weight[mul(och, WD231)] << FRAC_BIT;
					for (wy = 0; wy < weight_size.d2; ++wy)
						for (wx = 0; wx < weight_size.d3; ++wx)
						{
							signed int ix, iy;
							iy = wy + mul(oy, stride) - pad;
							ix = wx + mul(ox, stride) - pad;
							/* Can I believe that the compiler will optimize these two expressions? */
							if (ix >= 0 && ix < rd_size.d3 && iy >= 0 && iy < rd_size.d2)
								temp += mul(in[mul(ich, RD23) + mul(iy, rd_size.d3) + ix], weight[mul(och, mul(WD231, weight_size.d1)) + mul(ich, WD231) + mul(weight_size.d3, wy) + wx + 1]);
							/* '*' is still used here */
						}
					out[mul(och, Chw) + mul(oy, CBUF_W) + ox] = (short)(temp >> FRAC_BIT);
				}
		}
	}
}

unsigned int pooling()
{
	short *out = (short *)addr.wr_addr;

	unsigned output_offset = 0;
	unsigned input_offset = 0;

	unsigned input_fm_w = conv_size.d3;
	unsigned input_fm_h = conv_size.d2;

	unsigned pad = KERN_ATTR_POOL_PAD;
	unsigned pad_len = pad << 1;

	unsigned pad_w_test = conv_size.d3 - KERN_ATTR_POOL_KERN_SIZE;
	unsigned pad_h_test = conv_size.d2 - KERN_ATTR_POOL_KERN_SIZE;

	int och, ox, oy, kx, ky;
	unsigned int ymr = 0U;

	unsigned pool_out_w = pad_w_test + pad_len;
	unsigned pool_out_h = pad_h_test + pad_len;

	unsigned stride = KERN_ATTR_POOL_STRIDE;

	unsigned pad_w_test_remain = pad_w_test - mul(div(pad_w_test, stride), stride);
	unsigned pad_h_test_remain = pad_h_test - mul(div(pad_h_test, stride), stride);

	pool_out_w = div(pool_out_w, stride);
	pool_out_h = div(pool_out_h, stride);
	pool_out_w++;
	pool_out_h++;

	if ((!pad) && (pad_w_test_remain || pad_h_test_remain))
	{
		pool_out_w++;
		pool_out_h++;
	}

	//TODO: Please add your implementation here
	for (och = 0; och < WR_SIZE_D1; ++och)
	{	/* Output channel: 20 */
		for (oy = 0; oy < pool_out_h; ++oy)
			for (ox = 0; ox < pool_out_w; ++ox)
			{
				short max = SHT_MIN_G, temp;
				for (ky = 0; ky < KERN_ATTR_POOL_KERN_SIZE; ++ky)
					for (kx = 0; kx < KERN_ATTR_POOL_KERN_SIZE; ++kx)
					{	/* every cell of kernel */
						signed int ix, iy;
						iy = ky + mul(oy, stride) - pad;
						ix = kx + mul(ox, stride) - pad;
						if (ix >= 0 && ix < CBUF_W && iy >= 0 && iy < CBUF_H)
							if (max < (temp = out[mul(och, Chw) + mul(iy, CBUF_W) + ix]))
								max = temp;
					}
				out[mul(och, OD23) + mul(oy, WR_SIZE_D3) + ox] = max;
				++ymr;
			}
	}
	return ymr;
}

#ifdef USE_HW_ACCEL
void launch_hw_accel()
{
	volatile int* gpio_start = (void*)(GPIO_START_ADDR);	// Write only
	volatile int* gpio_done = (void*)(GPIO_DONE_ADDR);		// Read only

	//TODO: Please add your implementation here
	*gpio_start |= 1;	// Start
	while (*gpio_done & 1 == 0)
		;	// Waiting
	// Done
}
#endif

int comparing()
{
	char *out = (char *)addr.wr_addr;
	char *result = (char *)_binary_data_result_bin_start;

#ifdef USE_HW_ACCEL
	int count = (int)_binary_data_result_bin_size + 
		    (16 - WR_SIZE_D3) * 2 * WR_SIZE_D2 * WR_SIZE_D1;
#else
	int count = (int)_binary_data_result_bin_size;
#endif

	for (int i = 0, j = 0; i < count; i++)
	{
#ifdef USE_HW_ACCEL
		int alignment = i & 0x0000001f;
		if (alignment >= (WR_SIZE_D3 << 1))
			continue;
#endif
		if (*(out + i) != *(result + j))
		{
			printf("Failed! at address %x and %x with data %x and %x\n", out + i, result + j, *(out + i), *(result + j));
			return 1;
		}
		j++;
	}

	printf("Passed!\n");
	return 0;
}

int main()
{
	unsigned int ymr, i;
	Result brt;
	// Bus Rapid Transit ()*
	// Bench ReTurn
	bench_prepare(&brt);
#ifdef USE_HW_ACCEL
	printf("Launching task...\n");
	launch_hw_accel();
	bench_done(&brt);
#else
	printf("Starting convolution\n");
	convolution();
	printf("Starting pooling\n");
	ymr = pooling();
	bench_done(&brt);
	printf("\t%u bytes written\n", ymr);
#endif

	int result = comparing();
	printf("Benchmark finished:\n");
	for (i = 0; i < NCT; ++i)
	{
		printf("\t%s: %u\n", Label[i], brt.ymr[i]);
	}
	if (result == 0) {
		hit_good_trap();
	} else {
		nemu_assert(0);
	}

	return 0;
}
