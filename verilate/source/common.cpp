#include "common.h"

#include <cstdio>
#include <cstdarg>

static bool _log_enabled = false;

void enable_logging(bool enable) {
    _log_enabled = enable;
}

void info(const char *message, ...) {
    if (_log_enabled) {
        va_list args;
        va_start(args, message);
        vfprintf(stdout, message, args);
        va_end(args);
    }
}

void warn(const char *message, ...) {
    if (_log_enabled) {
        va_list args;
        va_start(args, message);
        vfprintf(stderr, message, args);
        va_end(args);
    }
}

void notify(const char *message, ...) {
    va_list args;
    va_start(args, message);
    vfprintf(stderr, message, args);
    va_end(args);
}
