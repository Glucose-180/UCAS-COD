#pragma once

static inline int div(int x, int y)
{
    int q = 0;
    while (x >= y) {
        q++;
        x -= y;
    }

    return q;
}
