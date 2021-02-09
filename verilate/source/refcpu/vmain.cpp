#include "thirdparty/CLI11.hpp"

#include "refcpu/top.h"

constexpr size_t MEMORY_SIZE = 1024 * 1024;  // 1 MiB

static std::string fst_trace_path = "" /*"/tmp/trace.fst"*/;
static std::string text_trace_path = "" /*"/tmp/trace.txt"*/;
static std::string ref_trace_path = "./misc/nscscc/func_test.txt";
static std::string memfile_path = "./misc/nscscc/func_test.coe";
static int status_countdown = 10000;
static bool status_enable = true;
static bool debug_enable = false;

static RefCPU *top;

void exit_handler() {
    if (!ref_trace_path.empty())
        top->close_reference_trace();
    if (!fst_trace_path.empty())
        top->stop_fst_trace();
    if (!text_trace_path.empty())
        top->stop_text_trace();
}

void abort_handler(int) {
    exit_handler();
}

int vmain(int argc, char *argv[]) {
    auto app = CLI::App();
    app.add_option("-f,--fst-trace", fst_trace_path, "File path to save FST trace.");
    app.add_option("-t,--text-trace", text_trace_path, "File path to save text trace.");
    app.add_option("-r,--ref-trace", ref_trace_path, "File path of reference text trace.");
    app.add_option("-m,--memfile", memfile_path, "File path of memory initialization file.");
    app.add_flag("--status,!--no-status", status_enable, "Show status line.");
    app.add_option("--status-count", status_countdown, "Slow down status line update.");
    app.add_flag("--debug,!--no-debug", debug_enable, "Show debug messages.");

    CLI11_PARSE(app, argc, argv);

    enable_logging();
    enable_status_line(status_enable);
    enable_debugging(debug_enable);
    set_status_countdown(status_countdown);

    top = new RefCPU();
    hook_signal(SIGABRT, abort_handler);
    atexit(exit_handler);

    auto data = parse_memory_file(memfile_path);
    auto mem = std::make_shared<BlockMemory>(MEMORY_SIZE, data);

    top->install_memory(std::move(mem));
    if (!ref_trace_path.empty())
        top->open_reference_trace(ref_trace_path);
    if (!fst_trace_path.empty())
        top->start_fst_trace(fst_trace_path);
    if (!text_trace_path.empty())
        top->start_text_trace(text_trace_path);

    top->run();

    return 0;
}
