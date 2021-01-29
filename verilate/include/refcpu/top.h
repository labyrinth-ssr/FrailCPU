#pragma once

#include "defs.h"
#include "context.h"

class RefCPU : public VRefCPU {
public:
    void tick(int count = 1);
    void run();

    auto get_ctx() const -> ContextWrapper {
        return ContextWrapper(VTop, VTop->core__DOT__ctx);
    }
    auto get_ctx0() const -> ContextWrapper {
        return ContextWrapper(VTop, VTop->core__DOT__proxy__DOT__ctx0);
    }
};
