
#ifndef __PERF_CNT__
#define __PERF_CNT__

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

typedef struct Result {
	int pass;
	unsigned long msec;			// cycle count
	unsigned long inst_ymr;		// instruction count
	unsigned long mainst_ymr;	// memory access instruction count
	unsigned long ldinst_ymr;	// load instruction count
	unsigned long stinst_ymr;	// store instruction count
	unsigned long ld_cycle_ymr;	// total load cycle count
	unsigned long st_cycle_ymr;	// total store cycle count
} Result;

extern volatile uint32_t* const Cycle_count;
extern volatile uint32_t* const Inst_count;
extern volatile uint32_t* const Mainst_count;
extern volatile uint32_t* const Ldinst_count;
extern volatile uint32_t* const Stinst_count;
extern volatile uint32_t* const Ld_cycle_count;
extern volatile uint32_t* const St_cycle_count;

void bench_prepare(Result *res);
void bench_done(Result *res);

#endif
