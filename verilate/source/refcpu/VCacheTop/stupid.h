#pragma once

#include "model.h"

#include "defs.h"

class StupidBuffer : public ModelBase {
public:
    void reset();
    void tick();
    void run();

private:
    uint64_t tickcount = 0;

    auto get_creq() const -> CBusWrapper {
        return CBusWrapper(VCacheTop, creq);
    }

    // template is used to reduce the number of unnecessary branches.
    // hope compilers optimizes those "if"s out.
    template <bool Memory = true, bool Trace = true>
    void _tick() {
        // see refcpu/VTop/refcpu.cpp for the descriptions of each stage.

        tickcount++;
        clk = 0;

        if (Memory)
            cresp = (CBusRespVType) dev->eval_resp();

        eval();

        if (Trace)
            fst_dump(+1);
        if (Memory)
            dev->eval_req(get_creq());

        clk = 1;

        if (Memory)
            dev->sync();

        eval();

        if (Trace) {
            fst_advance();
            fst_dump(+0);
        }
    }
};

using DBus = DBusGen<StupidBuffer, VModelScope>;

namespace _testbench {
    extern StupidBuffer *top;
    extern VModelScope *scope;
    extern DBus *dbus;
}
