#include "perf_cnt.h"

volatile uint32_t* const Cycle_count = (void *)0x60010000;
volatile uint32_t* const Inst_count = (void *)0x60010008;
volatile uint32_t* const Mainst_count = (void *)0x60011000;
volatile uint32_t* const Ldinst_count = (void *)0x60011008;
volatile uint32_t* const Stinst_count = (void *)0x60012000;
volatile uint32_t* const Ld_cycle_count = (void *)0x60012008;
volatile uint32_t* const St_cycle_count = (void *)0x60013000;

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
	res->ldinst_ymr = *Ldinst_count;
	res->stinst_ymr = *Stinst_count;
	res->ld_cycle_ymr = *Ld_cycle_count;
	res->st_cycle_ymr = *St_cycle_count;
}

void bench_done(Result *res) {
	// TODO [COD]
	//  Add postprocess code, record performance counters' current states.
	res->msec = _uptime() - res->msec;
	res->inst_ymr = *Inst_count - res->inst_ymr;
	res->mainst_ymr = *Mainst_count - res->mainst_ymr;
	res->ldinst_ymr = *Ldinst_count - res->ldinst_ymr;
	res->stinst_ymr = *Stinst_count - res->stinst_ymr;
	res->ld_cycle_ymr = *Ld_cycle_count - res->ld_cycle_ymr;
	res->st_cycle_ymr = *St_cycle_count - res->st_cycle_ymr;
}

