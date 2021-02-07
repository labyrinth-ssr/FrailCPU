#pragma once

#include <string>
#include <vector>

#include <cassert>
#include <cstdint>

using addr_t = uint32_t;
using word_t = uint32_t;
using ByteSeq = std::vector<uint8_t>;

auto parse_memory_file(const std::string &path) -> ByteSeq;

/**
 * basic logging
 *
 * info: write to stdout.
 * warn: write to stderr.
 * notify: write to stderr, not controlled by the enable flag.
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
