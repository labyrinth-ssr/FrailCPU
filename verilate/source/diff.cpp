#include "diff.h"

#include <filesystem>

auto TextDiff::is_open() const -> bool {
    return fs && fs.is_open();
}

void TextDiff::open(const std::string &path) {
    assert(!is_open());
    fs.open(path);
    assert(fs);

    line_number = 0;
    byte_read = 0;
    file_size = std::filesystem::file_size(path);
}

void TextDiff::close() {
    assert(is_open());
    fs.close();
}

auto TextDiff::get_line() -> std::string {
    std::string buf;

    do {
        std::getline(fs, buf);
        byte_read += buf.size() + 1;

        buf = trim(buf);
        line_number++;
    } while (!fs.eof() && buf.empty());

    return buf;
}

static auto eof_indicator(const std::string &line) -> const char * {
    return line.empty() ? " (EOF)" : "";
}

auto TextDiff::check_line(const std::string &line, bool report) -> bool {
    if (!is_open())
        return true;

    auto ref = get_line();
    bool same = line == ref;

    if (!same && report) {
        log_separator();
        warn("TextDiff: on line %zu:\n", line_number);
        warn("\texpect: \"%s\"%s\n", ref.data(), eof_indicator(ref));
        warn("\t   got: \"%s\"%s\n", line.data(), eof_indicator(line));
        abort();
    }

    return same;
}

auto TextDiff::check_eof(bool report) -> bool {
    return check_line("", report);
}

auto TextDiff::current_progress() const -> int {
    if (is_open())
        return 100 * byte_read / file_size;
    else
        return 100;
}

auto TextDiff::current_line() const -> size_t {
    return line_number + 1;
}
