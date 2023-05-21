
#ifndef __PERF_CNT__
#define __PERF_CNT__

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

#define NCT 10
// number of counters

typedef struct Result {
	int pass;
	unsigned int ymr[NCT];	// counters
} Result;

extern const char* const Label[NCT];

void bench_prepare(Result *res);
void bench_done(Result *res);

#endif
