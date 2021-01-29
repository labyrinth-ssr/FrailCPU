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

    auto print_ctx = [this](int i) {
        auto ctx = get_ctx();
        info(GREEN "[i=%d]" RESET " state=%u, pc=%08x, next_pc=%08x\n",
            i, ctx.state(), ctx.pc(), ctx.next_pc());
    };

    enable_logging(true);

    print_ctx(0);
    for (int i = 1; i <= 16; i++) {
        tick();
        print_ctx(i);
    }

    final();
}
