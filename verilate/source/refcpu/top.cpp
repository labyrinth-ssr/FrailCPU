#include "refcpu/top.h"

#include <cstring>

RefCPU::RefCPU(size_t memory_size)
    : mem(std::make_unique<Memory>(new BlockMemory(memory_size))) {}

void RefCPU::eval_memory() {
    oresp = mem->eval(get_oreq());
}

void RefCPU::tick(int count) {
    while (count--) {
        clk = 0;
        eval_memory();  // to update oresp
        eval();

        auto req = get_oreq();
        if (resetn && req.valid()) {
            info(
                BLUE "[%s]" RESET " "
                "addr=%08x, data=%08x, len=%u, size=%u, strb=%x\n",
                req.is_write() ? "W" : "R",
                req.addr(),
                req.data(),
                static_cast<uint32_t>(req.len()) + 1,
                1u << static_cast<uint32_t>(req.size()),
                req.strobe()
            );
        }

        eval_memory();  // to process oreq

        mem->commit();
        clk = 1;
        eval();
    }
}

void RefCPU::run() {
    mem->reset();
    clk = 0;
    resetn = 0;
    oresp = 0;
    tick(10);  // 10 cycles to reset

    auto print_ctx = [this](int i) {
        auto ctx = get_ctx();
        info(GREEN "[i=%d]" RESET " state=%u, pc=%08x\n",
            i, ctx.state(), ctx.pc());
    };

    enable_logging(true);

    clk = 0;
    resetn = 1;
    eval();
    print_ctx(0);

    for (int i = 1; i <= 16; i++) {
        tick();
        print_ctx(i);
    }

    final();
}
