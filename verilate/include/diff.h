#pragma once

#include "common.h"

#include <string>
#include <fstream>

class TextDiff {
public:
    auto is_open() -> bool;
    void open(const std::string &path);
    void close();

    auto check_line(const std::string &line, bool report = true) -> bool;
    auto check_eof(bool report = true) -> bool;

    auto current_progress() -> int {
        if (is_open())
            return 100 * byte_read / file_size;
        else
            return 100;
    }
    auto current_line() -> size_t {
        return line_number + 1;
    }

private:
    size_t line_number;
    size_t file_size, byte_read;
    std::ifstream fs;

    auto get_line() -> std::string;
};
