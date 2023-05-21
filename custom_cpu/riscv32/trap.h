#ifndef __TRAP_H__
#define __TRAP_H__

void _halt(int i) {
    extern int global_result;
    global_result = i;
    for (;;) {}
}

__attribute__((noinline))
void nemu_assert(int cond) {
  if (!cond) {
      _halt(1);
  }
}

void hit_good_trap() {
    _halt(0);
}

#endif
