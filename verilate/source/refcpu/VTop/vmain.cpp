#include "refcpu.h"

#include "thirdparty/CLI11.hpp"

constexpr size_t MEMORY_SIZE = 1024 * 1024;  // 1 MiB

static struct {
    std::string fst_trace_path = "" /*"/tmp/trace.fst"*/;
    std::string text_trace_path = "" /*"/tmp/trace.txt"*/;
    std::string ref_trace_path = "./misc/nscscc/func_test.txt";
    std::string memfile_path = "./misc/nscscc/func_test.coe";
    int status_countdown = 10000;
    bool status_enable = true;
    bool debug_enable = false;
    float p_disable = 0.0f;
    bool force_diff = false;
} args;

static RefCPU *top;

void exit_handler() {
    top->stop_fst_trace();
    top->stop_text_trace();
    top->close_text_diff();
}

void abort_handler(int) {
    exit_handler();
}

int vmain(int argc, char *argv[]) {
    auto app = CLI::App();
    app.add_option("-f,--fst-trace", args.fst_trace_path, "File path to save FST trace.");
    app.add_option("-t,--text-trace", args.text_trace_path, "File path to save text trace.");
    app.add_option("-r,--ref-trace", args.ref_trace_path, "File path of reference text trace.");
    app.add_option("-m,--memfile", args.memfile_path, "File path of memory initialization file.");
    app.add_flag("--status,!--no-status", args.status_enable, "Show status line.");
    app.add_option("--status-count", args.status_countdown, "Slow down status line update.");
    app.add_flag("--debug,!--no-debug", args.debug_enable, "Show debug messages.");
    app.add_option("-p,--p-disable", args.p_disable, "Probability that CBusDevice pause in a cycle. Set to 0 to disable random delay.");
    app.add_flag("--force-diff,!--no-force-diff", args.force_diff, "Ignore OPEN_TRACE bit from Confreg.");

    CLI11_PARSE(app, argc, argv);

    hook_signal(SIGABRT, abort_handler);
    atexit(exit_handler);

    enable_logging();
    enable_status_line(args.status_enable);
    enable_debugging(args.debug_enable);
    set_status_countdown(args.status_countdown);

    top = new RefCPU();
    top->p_disable = args.p_disable;
    top->force_diff = args.force_diff;

    auto data = parse_memory_file(args.memfile_path);
    auto mem = std::make_shared<BlockMemory>(MEMORY_SIZE, data);

    top->install_memory(std::move(mem));
    if (!args.ref_trace_path.empty())
        top->open_text_diff(args.ref_trace_path);
    if (!args.fst_trace_path.empty())
        top->start_fst_trace(args.fst_trace_path);
    if (!args.text_trace_path.empty())
        top->start_text_trace(args.text_trace_path);

    top->run();

    return 0;
}
