#pragma once

#include "defs.h"

class RefCPU : public VRefCPU {
public:
    void tick(int count = 1);
    void run();

    auto get_ctx() const -> Context {
        return Context(VTop, VTop->core__DOT__ctx);
    }
    auto get_ctx0() const -> Context {
        return Context(VTop, VTop->core__DOT__proxy__DOT__ctx0);
    }
};
