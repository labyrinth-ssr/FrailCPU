#include "common.h"

#include <cstdio>
#include <cassert>
#include <cstdarg>
#include <sstream>
#include <fstream>

#include <errno.h>
#include <unistd.h>

void hook_signal(int sig, handler_t *handler) {
    struct sigaction action;

    action.sa_handler = handler;
    sigemptyset(&action.sa_mask);
    action.sa_flags = SA_RESTART;

    assert(sigaction(sig, &action, NULL) >= 0);
}

/*
static bool startswith(const std::string &text, const std::string &pattern) {
    for (size_t i = 0; i < pattern.size(); i++) {
        if (i >= text.size() || text[i] != pattern[i])
            return false;
    }
    return true;
}
*/

static bool endswith(const std::string &text, const std::string &pattern) {
    for (size_t i = 0; i < pattern.size(); i++) {
        if (i >= text.size() ||
            text[text.size() - i - 1] != pattern[pattern.size() - i - 1])
            return false;
    }
    return true;
}

auto trim(const std::string &text) -> std::string {
    size_t i, j;
    for (i = 0; i < text.size(); i++) {
        if (std::isalnum(text[i]))
            break;
    }
    for (j = text.size(); j > i; j--) {
        if (std::isalnum(text[j - 1]))
            break;
    }
    return text.substr(i, j - i);
}

static void feed(ByteSeq &seq, std::ifstream &fp, int base) {
    std::string buf;

    while (std::getline(fp, buf)) {
        buf = trim(buf);
        if (buf.empty())
            continue;

        size_t count = 0;
        uint64_t data = std::stoull(buf, &count, base);
        assert(count == buf.size());
        assert((data & 0xffffffff) == data);

        for (size_t i = 0; i < 4; i++) {
            seq.push_back(data & 0xff);
            data >>= 8;
        }
    }
}

static auto parse_coe(std::ifstream &fp) -> ByteSeq {
    std::string buf;

    // first line
    std::getline(fp, buf);

    {
        std::istringstream bs(buf);
        std::getline(bs, buf, '=');
        assert(trim(buf) == "memory_initialization_radix");
        std::getline(bs, buf);
    }

    int base = std::stoi(buf);

    // second line
    std::getline(fp, buf);

    {
        std::istringstream bs(buf);
        std::getline(bs, buf, '=');
        assert(trim(buf) == "memory_initialization_vector");
    }

    // data
    ByteSeq seq;
    feed(seq, fp, base);
    return seq;
}

static auto parse_mif(std::ifstream &fp) -> ByteSeq {
    ByteSeq seq;
    feed(seq, fp, 2);
    return seq;
}

static auto parse_hex(std::ifstream &fp) -> ByteSeq {
    ByteSeq seq;
    feed(seq, fp, 16);
    return seq;
}

static auto parse_bin(std::ifstream &fp) -> ByteSeq {
    ByteSeq seq;
    std::ifstream::char_type c;
    while (fp.get(c)) {
        seq.push_back(static_cast<uint8_t>(c));
    }
    return seq;
}

auto parse_memory_file(const std::string &path) -> ByteSeq {
    std::ifstream fp(path);

    if (endswith(path, ".coe"))
        return parse_coe(fp);
    else if (endswith(path, ".mif"))
        return parse_mif(fp);
    else if (endswith(path, ".hex"))
        return parse_hex(fp);
    else
        return parse_bin(fp);
}

static bool _log_enabled = false;
static bool _in_status_line = false;

static void check_status_line(FILE *fp) {
    if (_in_status_line) {
        fprintf(fp, CLEAR_ALL MOVE_TO_FRONT);
        _in_status_line = false;
    }
}

void enable_logging(bool enable) {
    _log_enabled = enable;
}

void info(const char *message, ...) {
    if (_log_enabled) {
        check_status_line(stdout);

        va_list args;
        va_start(args, message);
        vfprintf(stdout, message, args);
        va_end(args);
    }
}

void warn(const char *message, ...) {
    if (_log_enabled) {
        check_status_line(stderr);

        va_list args;
        va_start(args, message);
        vfprintf(stderr, message, args);
        va_end(args);
    }
}

void notify(const char *message, ...) {
    check_status_line(stderr);

    va_list args;
    va_start(args, message);
    vfprintf(stderr, message, args);
    va_end(args);
}

void status_line(const char *message, ...) {
    va_list args;
    va_start(args, message);

    _in_status_line = true;
    fprintf(stdout, MOVE_TO_FRONT);
    vfprintf(stdout, message, args);
    fprintf(stdout, CLEAR_TO_RIGHT " ");
    fflush(stdout);

    va_end(args);
}

void log_separator() {
    fputs("\n", stdout);
    fputs("\n", stderr);
}
