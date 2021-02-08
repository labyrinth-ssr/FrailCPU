#include "refcpu/top.h"

#include "thirdparty/nameof.hpp"

constexpr int MAX_CYCLE = 100000000;
constexpr addr_t TEST_END_PC = 0xbfc00100;

void RefCPU::print_request() {
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
}

void RefCPU::print_writeback() {
    // print register writeback
    auto ctx = get_new_ctx();
    if (ctx.target_id() != RegisterID::R0) {
        auto id = ctx.target_id();
        auto value = ctx.r(id);
        info("R[%d \"%s\"] <- %08x\n",
            id, nameof::nameof_enum(id).data(), value);
        text_trace_dump(ctx.pc(), id, value);
    }
}

void RefCPU::check_monitor() {
    int num = con->get_current_num();
    int ack = con->get_acked_num();
    if (current_num != num) {
        assert(current_num + 1 == num);
        notify(BLUE "(info)" RESET " #%d has completed.\n", num);
        assert(ack == num);
        current_num = num;
    }
}

void RefCPU::_tick() {
    if (test_finished)
        return;

    // update response from memory
    clk = 0;
    oresp = dev->eval_resp();
    eval();

    trace_dump(+1);

    // print_request();
    print_writeback();
    check_monitor();

    // check for the end of tests
    if (get_ctx().pc() == TEST_END_PC + 4 ||
        (con->has_char() && con->get_char() == 0xff)) {
        test_finished = true;
        return;
    }

    // send request to memory
    dev->eval_req(get_oreq());

    // clock posedge trigger
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
        status_line(GREEN "[%d]" RESET " pc=%08x, ack=%zu, instr=%08x, state=%s",
            i, ctx.pc(), diff.current_line(), ctx.instr(),
            nameof::nameof_enum(ctx.state()).data()
        );
    };

    // enable_logging(true);

    clk = 0;
    resetn = 1;
    eval();
    print_ctx(0);

    for (int i = 1; i <= MAX_CYCLE && !test_finished && !Verilated::gotFinish(); i++) {
        tick();
        print_ctx(i);
    }

    diff.check_eof();
    final();

    notify(BLUE "(info)" RESET " All tests have completed.\n");
}
