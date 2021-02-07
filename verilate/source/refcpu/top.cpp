#include "refcpu/top.h"
#include "verilated.h"
#include "verilated_fst_c.h"

#include <cstring>

#include "thirdparty/nameof.hpp"

constexpr int MAX_TRACE_DEPTH = 32;

RefCPU::RefCPU(const std::shared_ptr<BlockMemory> &mem)
    : tfp(nullptr), text_tfp(nullptr), trace_count(0) {
    con = std::make_shared<Confreg>();
    std::vector<MemoryRouter::Entry> layout = {
        {0xfff00000, 0x1fc00000, mem},
        {0xffff0000, 0x1faf0000, con},
    };
    auto router = std::make_shared<MemoryRouter>(layout);
    dev = std::make_shared<CBusDevice>(router);
}

RefCPU::~RefCPU() {
    if (tfp)
        stop_trace();
    if (text_tfp)
        stop_text_trace();
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

void RefCPU::start_text_trace(const std::string &path) {
    assert(!text_tfp);
    text_tfp = fopen(path.data(), "w");
}

void RefCPU::stop_text_trace() {
    assert(text_tfp);
    fclose(text_tfp);
    text_tfp = nullptr;
}

void RefCPU::text_trace_dump(addr_t pc, RegisterID id, word_t value) {
    if (text_tfp)
        fprintf(text_tfp, "1 %08x %02x %08x\n", pc, id, value);
}

void RefCPU::_tick() {
    clk = 0;
    oresp = dev->eval_resp();
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
            static_cast<word_t>(req.len()) + 1,
            1u << static_cast<word_t>(req.size()),
            req.strobe()
        );
    }

    auto ctx = get_new_ctx();
    if (ctx.target_id() != RegisterID::R0) {
        auto id = ctx.target_id();
        auto value = ctx.r(id);
        info("R[%d] <- %08x\n", id, value);
        text_trace_dump(ctx.pc(), id, value);
    }

    dev->eval_req(req);

    dev->commit();
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
    dev->reset();
    clk = 0;
    resetn = 0;
    oresp = 0;
    tick(10);  // 10 cycles to reset

    auto print_ctx = [this](int i) {
        auto ctx = get_ctx();
        info(GREEN "[i=%d]" RESET " pc=%08x, instr=%08x, state=%s\n",
            i, ctx.pc(), ctx.instr(),
            nameof::nameof_enum(ctx.state()).data()
        );
    };

    enable_logging(true);

    clk = 0;
    resetn = 1;
    eval();
    print_ctx(0);

    for (int i = 1; i <= 8192 && !Verilated::gotFinish(); i++) {
        tick();
        print_ctx(i);
    }

    final();
}
