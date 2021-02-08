#pragma once

#include <string>
#include <vector>

#include <cassert>
#include <cstdint>

#include <signal.h>

using addr_t = uint32_t;
using word_t = uint32_t;
using handler_t = void(int);
using uchar = unsigned char;

using ByteSeq = std::vector<uint8_t>;

void hook_signal(int sig, handler_t *handler);
auto trim(const std::string &text) -> std::string;
auto parse_memory_file(const std::string &path) -> ByteSeq;

template <typename T>
auto identity_fn(T x) -> T {
    return x;
}

/**
 * basic logging
 *
 * info: write to stdout.
 * warn: write to stderr.
 * notify: write to stderr, not controlled by the enable flag.
 * status_line: write a line with clear and no '\n' to stdout.
 */

// ANSI Escape sequences for colors
// https://en.wikipedia.org/wiki/ANSI_escape_code#Colors
#define BLACK   "\033[30m"
#define RED     "\033[31m"
#define GREEN   "\033[32m"
#define YELLOW  "\033[33m"
#define BLUE    "\033[34m"
#define MAGENTA "\033[35m"
#define CYAN    "\033[36m"
#define WHITE   "\033[37m"
#define RESET   "\033[0m"

#define CLEAR_TO_RIGHT "\033[K"
#define CLEAR_ALL      "\033[2K"
#define MOVE_TO_FRONT  "\r"

#define LOG { \
    enable_logging(true); \
    _.defer([] { \
        enable_logging(false); \
    }); \
}

void enable_logging(bool enable = true);
void info(const char *message, ...);
void warn(const char *message, ...);
void notify(const char *message, ...);
void status_line(const char *message, ...);
void log_separator();
