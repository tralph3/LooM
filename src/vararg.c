#include <stdio.h>
#include <stdarg.h>

#define BUFFER_SIZE 4096

extern void odin_log_callback(int log_level, const char *msg, int n);

void c_log_callback(int log_level, const char *fmt, ...) {
    va_list ap;

    va_start(ap, fmt);
    char buf[BUFFER_SIZE];
    int n = vsnprintf(buf, BUFFER_SIZE, fmt, ap);
    va_end(ap);

    if (n > BUFFER_SIZE) {
        n = BUFFER_SIZE;
    }

    odin_log_callback(log_level, buf, n);
}
