#include "refcpu/top.h"

constexpr size_t MEMORY_SIZE = 4096;

void vmain(int /*argc*/, char */*argv*/[]) {
    auto top = new RefCPU(MEMORY_SIZE);
    top->start_trace("/tmp/test.fst");
    top->run();
    top->stop_trace();
}
