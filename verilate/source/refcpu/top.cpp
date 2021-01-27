#include "refcpu/top.h"

#include <cstring>

void RefCPU::tick(int count) {
    while (count--) {
        clk = 0;
        eval();
        clk = 1;
        eval();
        clk = 0;
        eval();
    }
}

void RefCPU::run() {
    clk = 0;
    resetn = 0;
    oresp = 0;
    tick(10);  // 10 cycles to reset

    auto print_ctx = [this]() {
        auto ctx = get_ctx();
        printf("pc=%08x, next_pc=%08x\n", ctx.pc(), ctx.next_pc());
    };

    print_ctx();
    for (int i = 0; i < 10; i++) {
        tick();
        print_ctx();
    }

    final();
}
