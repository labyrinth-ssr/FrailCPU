#include "thirdparty/CLI11.hpp"

#include "refcpu/top.h"

constexpr size_t MEMORY_SIZE = 4096;

int vmain(int argc, char *argv[]) {
    std::string trace_path = "/tmp/trace.fst";
    std::string text_trace_path = "/tmp/trace.txt";
    std::string memfile_path = "./asset/nscscc/func_test.coe";

    auto app = CLI::App();
    app.add_option("-f,--fst-trace", trace_path, "file path to save FST trace.");
    app.add_option("-t,--text-trace", text_trace_path, "file path to save text trace.");
    app.add_option("-m,--memfile", memfile_path, "file path of memory initialization file.");

    CLI11_PARSE(app, argc, argv);

    auto data = parse_memory_file(memfile_path);
    auto mem = std::make_shared<BlockMemory>(data, 0x1fc00000);
    auto top = new RefCPU(std::move(mem));

    top->start_trace(trace_path);
    top->start_text_trace(text_trace_path);
    top->run();
    top->stop_trace();
    top->stop_text_trace();

    return 0;
}
