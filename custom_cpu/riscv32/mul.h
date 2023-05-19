#pragma once

#define mul_tmpl(suffix, ty) static inline ty mul_##suffix(ty x, ty y) \
{ \
    ty sign = (y > 0) ? 1 : -1; \
    y = (y > 0) ? y : -y; \
    ty result = 0; \
    for (unsigned i = 0; i < (sizeof(y) << 3); i++) { \
        ty b = y & 0x1; \
        if (b) result += x << i; \
        y = y >> 1; \
    } \
    return sign > 0 ? result : -result; \
}

mul_tmpl(i, int)
mul_tmpl(ll, long long)
