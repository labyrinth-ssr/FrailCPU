#pragma once

#include "defs.h"

using ContextVType = decltype(VRefCPU::VTop->core__DOT__ctx);

struct ContextWrapper {
    ContextWrapper(VTopType *_top, const ContextVType &_data)
        : top(_top), data(_data) {}

    auto state() const -> CPUState {
        return static_cast<CPUState>(top->context_t_state(data));
    }
    auto pc() const -> uint32_t {
        return top->context_t_pc(data);
    }

protected:
    VTopType *top;
    const ContextVType &data;
};
