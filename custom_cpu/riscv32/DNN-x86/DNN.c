#include "DNN.h"

#define CBUF_H WR_SIZE_D2 * KERN_ATTR_POOL_KERN_SIZE
#define CBUF_W WR_SIZE_D3 * KERN_ATTR_POOL_KERN_SIZE

static int conv_buf[WR_SIZE_D1][CBUF_H][CBUF_W];
/* NOTE: there has 2*FRAC_BIT frac bits */

static const unsigned WD231 = WEIGHT_SIZE_D2 * WEIGHT_SIZE_D3 + 1;
static const unsigned RD23 = RD_SIZE_D2 * RD_SIZE_D3;
static const unsigned OD23 = WR_SIZE_D2 * WR_SIZE_D3;

static inline int mul(int a, int b)
{
#ifdef SOFT_MUL
	int ans = mul_ll(a, b);
#else
	int ans = a * b;
#endif
	return ans;
}

static inline int div(int x, int y)
{
    int q = 0;

    while (x >= y) {
        q++;
        x -= y;
    }
    return q;
}

struct mem_addr addr;
struct size_vec4 rd_size = {RD_SIZE_D0, RD_SIZE_D1, RD_SIZE_D2, RD_SIZE_D3};
struct size_vec4 wr_size = {WR_SIZE_D0, WR_SIZE_D1, WR_SIZE_D2, WR_SIZE_D3};
struct size_vec4 weight_size = {WEIGHT_SIZE_D0, WEIGHT_SIZE_D1, WEIGHT_SIZE_D2, WEIGHT_SIZE_D3};

struct size_vec4 conv_size;

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

	unsigned conv_out_w = rd_size.d3 - weight_size.d3 + 1 + pad_len;
	unsigned conv_out_h = rd_size.d2 - weight_size.d2 + 1 + pad_len;

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
					if (ich == 0)	/* bias */
						conv_buf[och][oy][ox] = weight[mul(och, WD231)] << FRAC_BIT;
					for (wy = 0; wy < weight_size.d2; ++wy)
						for (wx = 0; wx < weight_size.d3; ++wx)
						{
							signed int ix, iy;
							iy = wy + mul(oy, stride) - pad;
							ix = wx + mul(ox, stride) - pad;
							/* Can I believe that the compiler will optimize these two expressions? */
							if (ix >= 0 && ix < rd_size.d3 && iy >= 0 && iy < rd_size.d2)
								conv_buf[och][oy][ox] += in[mul(ich, RD23) + mul(iy, rd_size.d3) + ix] * weight[mul(och, mul(WD231, weight_size.d1)) + mul(ich, WD231) + mul(weight_size.d3, wy) + wx + 1];
							/* '*' is still used here */
						}
				}
		}
	}
}

void pooling()
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

	unsigned pool_out_w = pad_w_test + pad_len;
	unsigned pool_out_h = pad_h_test + pad_len;

	unsigned stride = KERN_ATTR_POOL_STRIDE;

	unsigned pad_w_test_remain = pad_w_test - mul(div(pad_w_test, stride), stride);
	unsigned pad_h_test_remain = pad_h_test - mul(div(pad_h_test, stride), stride);

	int och, ox, oy, kx, ky;

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
				signed int max = INT_MIN_G;
				for (ky = 0; ky < KERN_ATTR_POOL_KERN_SIZE; ++ky)
					for (kx = 0; kx < KERN_ATTR_POOL_KERN_SIZE; ++kx)
					{	/* every cell of kernel */
						signed int ix, iy;
						iy = ky + mul(oy, stride) - pad;
						ix = kx + mul(ox, stride) - pad;
						if (ix >= 0 && ix < CBUF_W && iy >= 0 && iy < CBUF_H)
							if (max < conv_buf[och][iy][ix])
								max = conv_buf[och][iy][ix];
					}
				out[mul(och, OD23) + mul(oy, WR_SIZE_D3) + ox] = (short)(max >> FRAC_BIT);
			}
	}
}
