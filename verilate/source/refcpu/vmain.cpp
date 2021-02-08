#include "thirdparty/CLI11.hpp"

#include "refcpu/top.h"

constexpr size_t MEMORY_SIZE = 1024 * 1024;  // 1 MiB

int vmain(int argc, char *argv[]) {
    std::string trace_path = "/tmp/trace.fst";
    std::string text_trace_path = "/tmp/trace.txt";
    std::string ref_trace_path = "./asset/nscscc/func_test.txt";
    std::string memfile_path = "./asset/nscscc/func_test.coe";

    auto app = CLI::App();
    app.add_option("-f,--fst-trace", trace_path, "File path to save FST trace.");
    app.add_option("-t,--text-trace", text_trace_path, "File path to save text trace.");
    app.add_option("-r,--ref-trace", ref_trace_path, "File path of reference text trace.");
    app.add_option("-m,--memfile", memfile_path, "File path of memory initialization file.");

    CLI11_PARSE(app, argc, argv);

    auto top = new RefCPU();

    auto data = parse_memory_file(memfile_path);
    auto mem = std::make_shared<BlockMemory>(MEMORY_SIZE, data);

    top->install_memory(std::move(mem));
    top->open_reference_trace(ref_trace_path);
    top->start_trace(trace_path);
    top->start_text_trace(text_trace_path);

    top->run();

    top->close_reference_trace();
    top->stop_trace();
    top->stop_text_trace();

    return 0;
}
