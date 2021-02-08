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

private:
    size_t line_number;
    std::ifstream fs;

    auto get_line() -> std::string;
};
