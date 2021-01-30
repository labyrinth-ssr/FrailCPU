#include "refcpu/top.h"
#include "verilated_fst_c.h"

#include <cstring>

#include "thirdparty/nameof.hpp"

constexpr int MAX_TRACE_DEPTH = 32;

RefCPU::RefCPU(size_t memory_size) :
    mem(std::make_unique<Memory>(new BlockMemory(memory_size))),
    tfp(nullptr), trace_count(0) {}

RefCPU::~RefCPU() {
    if (tfp)
        stop_trace();
}

void RefCPU::start_trace(const std::string &path) {
    assert(!tfp);

    tfp = new VerilatedFstC;
    trace_count = 0;
    trace(tfp, MAX_TRACE_DEPTH);
    tfp->open(path.data());

    trace_dump(+0);
}

void RefCPU::stop_trace() {
    assert(tfp);

    notify("trace: stop @%d\n", time());
    eval();
    tfp->dump(time() + 10);

    tfp->flush();
    tfp->close();
    tfp = nullptr;
}

void RefCPU::trace_dump(uint64_t t) {
    if (tfp)
        tfp->dump(time() + t);
}

void RefCPU::_tick() {
    clk = 0;
    oresp = mem->eval_resp();
    eval();

    trace_dump(+1);

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

    mem->eval_req(get_oreq());

    mem->commit();
    clk = 1;
    eval();

    trace_dump(+10);

    trace_count++;
}

void RefCPU::tick(int count) {
    while (count--) {
        _tick();
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
        info(GREEN "[i=%d]" RESET " state=%s, pc=%08x\n",
            i, nameof::nameof_enum(ctx.state()).data(), ctx.pc());
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
