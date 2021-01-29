#pragma once

#include "defs.h"

using ContextVType = decltype(VRefCPU::VTop->core__DOT__ctx);

struct ContextWrapper {
    ContextWrapper(VTopType *_top, const ContextVType &_data)
        : top(_top), data(_data) {}

    auto state() const -> uint32_t {
        return top->context_t_state(data);
    }
    auto pc() const -> uint32_t {
        return top->context_t_pc(data);
    }
    auto next_pc() const -> uint32_t {
        return top->context_t_next_pc(data);
    }

protected:
    VTopType *top;
    const ContextVType &data;
};
