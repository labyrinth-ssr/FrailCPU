#include "refcpu/top.h"

void vmain(int /*argc*/, char */*argv*/[]) {
    auto top = new RefCPU;
    top->run();
}
