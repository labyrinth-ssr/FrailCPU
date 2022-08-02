#include "thirdparty/nameof.hpp"

#include "mycpu.h"

constexpr int MAX_CYCLE = 100000000;
constexpr addr_t TEST_END_PC = 0x9fc00100;
constexpr addr_t TEST_END_PC_MASK = 0xdfffffff;

auto MyCPU::get_writeback_pc1() const -> addr_t {
    /**
     * TODO (Lab2) retrieve PC from verilated model :)
     */
    return VTop->core__DOT__writeback__DOT__pc[1];
}
auto MyCPU::get_writeback_pc2() const -> addr_t {
    /**
     * TODO (Lab2) retrieve PC from verilated model :)
     */
    return VTop->core__DOT__writeback__DOT__pc[0];
}

auto MyCPU::get_writeback_id1() const -> int {
    /**
     * TODO (Lab2) retrieve writeback register id from verilated model :)
     */
        return VTop->core__DOT__writeback__DOT__wa[1];

}
auto MyCPU::get_writeback_id2() const -> int {
    /**
     * TODO (Lab2) retrieve writeback register id from verilated model :)
     */
        return VTop->core__DOT__writeback__DOT__wa[0];

}

auto MyCPU::get_writeback_value1() const -> addr_t {
    /**
     * TODO (Lab2) retrieve writeback value from verilated model :)
     */
        return VTop->core__DOT__writeback__DOT__wd[1];
}
auto MyCPU::get_writeback_value2() const -> addr_t {
    /**
     * TODO (Lab2) retrieve writeback value from verilated model :)
     */
        return VTop->core__DOT__writeback__DOT__wd[0];
}

auto MyCPU::get_writeback_wen1() const -> word_t {
    /**
     * TODO (Lab2) retrieve writeback wen from verilated model :)
     */
    return VTop->core__DOT__writeback__DOT__wen[1]&&get_writeback_id1()!=0;
}

auto MyCPU::get_writeback_wen2() const -> word_t {
    /**
     * TODO (Lab2) retrieve writeback wen from verilated model :)
     */
    return VTop->core__DOT__writeback__DOT__wen[0]&&get_writeback_id2()!=0;
}

void MyCPU::print_status() {
    status_line(
        GREEN "[%d]" RESET " ack=%zu (%d%%), pc=%08x",
        current_cycle,
        get_text_diff().current_line(),
        get_text_diff().current_progress(),
        get_writeback_pc1(),get_writeback_pc2()
    );
}

void MyCPU::print_writeback() {
    auto pc1 = get_writeback_pc1();
    auto id1 = get_writeback_id1();
    auto value1 = get_writeback_value1();

    auto pc2 = get_writeback_pc2();
    auto id2 = get_writeback_id2();
    auto value2 = get_writeback_value2();

    if (get_writeback_wen1() != 0) {
        // log_debug("R[%d] <- %08x\n", id, value);
        text_dump(con->trace_enabled(), pc1, id1, value1);
    }
    if (get_writeback_wen2() != 0) {
        // log_debug("R[%d] <- %08x\n", id, value);
        text_dump(con->trace_enabled(), pc2, id2, value2);
    }
}

void MyCPU::reset() {
    dev->reset();
    clk = 0;
    resetn = 0;
    oresp = 0;
    ticks(200);  // 10 cycles to reset
}

void MyCPU::tick() {
    if (test_finished)
        return;

    // update response from memory
    clk = 0;
    oresp =  (CBusRespVType) dev->eval_resp();
    eval();
    fst_dump(+1);

    print_writeback();

    // send request to memory
    dev->eval_req(get_oreq());

    // sync with clock's posedge
    clk = 1;
    con->sync();
    dev->sync();
    eval();
    fst_advance();
    fst_dump(+0);

    checkout_confreg();

    // check for the end of tests
    if ((get_writeback_pc1() & TEST_END_PC_MASK) == TEST_END_PC + 4 ||
        (con->has_char() && con->get_char() == 0xff))
        test_finished = true;
        else if ((get_writeback_pc2() & TEST_END_PC_MASK) == TEST_END_PC + 4 ||
        (con->has_char() && con->get_char() == 0xff))
        test_finished = true;
}


void MyCPU::run() {
    SimpleTimer timer;

    reset();

    clk = 0;
    resetn = 1;
    eval();

    auto worker = ThreadWorker::at_interval(100, [this] {
        print_status();
    });

    for (
        current_cycle = 1;

        current_cycle <= MAX_CYCLE &&
        !test_finished &&
        !Verilated::gotFinish();

        current_cycle++
    ) {
        tick();
    }

    worker.stop();
    asserts(current_cycle <= MAX_CYCLE, "simulation reached MAX_CYCLE limit");
    diff_eof();
    final();

    if (get_text_diff().get_error_count() > 0) {
        warn(RED "(warn)" RESET " TextDiff: %zu error(s) suppressed.\n",
            get_text_diff().get_error_count());
    }

    timer.update(current_cycle);
}
