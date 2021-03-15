#include "testbench.h"

#include "defs.h"
#include "stupid.h"

extern StupidBuffer *top;

void StupidBuffer::reset() {
    dev->reset();
    clk = 0;
    resetn = 0;
    cresp = 0;
    memset(dreq, 0, sizeof(dreq));
    ticks(10);
}

void StupidBuffer::tick() {
    // see refcpu/VTop/refcpu.cpp for the descriptions of each stage.

    clk = 0;
    cresp = (CBusRespVType) dev->eval_resp();
    eval();
    fst_dump(+1);

    dev->eval_req(get_creq());

    clk = 1;
    dev->sync();
    eval();
    fst_advance();
    fst_dump(+0);
}

void StupidBuffer::run() {
    top = this;
    run_testbench();
}
