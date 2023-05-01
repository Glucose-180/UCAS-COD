#include "perf_cnt.h"

volatile uint32_t* const Cycle_count = (void *)0x60010000;
volatile uint32_t* const Inst_count = (void *)0x60010008;
volatile uint32_t* const Mainst_count = (void *)0x60011000;

static inline unsigned long _uptime() {
	// TODO [COD]
	//   You can use this function to access performance counter related with time or cycle.
	return (*Cycle_count);
}

void bench_prepare(Result *res) {
	// TODO [COD]
	//   Add preprocess code, record performance counters' initial states.
	//   You can communicate between bench_prepare() and bench_done() through
	//   static variables or add additional fields in `struct Result`
	res->msec = _uptime();
	res->inst_ymr = *Inst_count;
	res->mainst_ymr = *Mainst_count;
}

void bench_done(Result *res) {
	// TODO [COD]
	//  Add postprocess code, record performance counters' current states.
	res->msec = _uptime() - res->msec;
	res->inst_ymr = *Inst_count - res->inst_ymr;
	res->mainst_ymr = *Mainst_count - res->mainst_ymr;
}

