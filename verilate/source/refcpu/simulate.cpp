#include "refcpu/top.h"

#include "thirdparty/nameof.hpp"

void RefCPU::_tick() {
    clk = 0;
    oresp = dev->eval_resp();
    eval();

    trace_dump(+1);

    auto req = get_oreq();

    // if (resetn && req.valid()) {
    //     info(
    //         BLUE "[%s]" RESET " "
    //         "addr=%08x, data=%08x, len=%u, size=%u, strb=%x\n",
    //         req.is_write() ? "W" : "R",
    //         req.addr(),
    //         req.data(),
    //         static_cast<word_t>(req.len()) + 1,
    //         1u << static_cast<word_t>(req.size()),
    //         req.strobe()
    //     );
    // }

    auto ctx = get_new_ctx();
    if (ctx.target_id() != RegisterID::R0) {
        auto id = ctx.target_id();
        auto value = ctx.r(id);
        info("R[%d \"%s\"] <- %08x\n",
            id, nameof::nameof_enum(id).data(), value);
        text_trace_dump(ctx.pc(), id, value);
    }

    dev->eval_req(req);

    clk = 1;
    con->update();
    dev->commit();
    eval();

    trace_dump(+10);

    trace_count++;
}

void RefCPU::run() {
    dev->reset();
    clk = 0;
    resetn = 0;
    oresp = 0;
    tick(10);  // 10 cycles to reset

    auto print_ctx = [this](int i) {
        auto ctx = get_ctx();
        status_line(GREEN "[i=%d]" RESET " pc=%08x, instr=%08x, state=%s",
            i, ctx.pc(), ctx.instr(),
            nameof::nameof_enum(ctx.state()).data()
        );
    };

    enable_logging(true);

    clk = 0;
    resetn = 1;
    eval();
    print_ctx(0);

    for (int i = 1; i <= 100000 && !Verilated::gotFinish(); i++) {
        tick();
        print_ctx(i);
    }

    diff.check_eof();
    final();
}
