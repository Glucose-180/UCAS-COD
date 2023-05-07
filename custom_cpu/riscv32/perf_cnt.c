#include "perf_cnt.h"

static volatile uint32_t* const Counter[NCT] = {
	(void *)0x60010000, (void *)0x60010008,
	(void *)0x60011000, (void *)0x60011008,
	(void *)0x60012000, (void *)0x60012008,
	(void *)0x60013000,
};

const char* const Label[NCT] = {
	"Cycle count", "Instruction count",
	"Memory access instruction count",
	"Load instruction count", "Store instruction count",
	"Total load cycle", "Total store cycle"
};

/*static inline unsigned long _uptime() {
	// TODO [COD]
	//   You can use this function to access performance counter related with time or cycle.
	return (*Cycle_count);
}*/

void bench_prepare(Result *res) {
	// TODO [COD]
	//   Add preprocess code, record performance counters' initial states.
	//   You can communicate between bench_prepare() and bench_done() through
	//   static variables or add additional fields in `struct Result`
	unsigned int i;

	for (i = 0; i < NCT; ++i)
		res->ymr[i] = *Counter[i];
}

void bench_done(Result *res) {
	// TODO [COD]
	//  Add postprocess code, record performance counters' current states.
	unsigned int i;

	for (i = 0; i < NCT; ++i)
		res->ymr[i] = *Counter[i] - res->ymr[i];
}

