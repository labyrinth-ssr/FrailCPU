#pragma once

#include "common.h"

#include "VRefCPU.h"
#include "VRefCPU_VTop.h"

using VTopType = VRefCPU_VTop;

using ContextVType = decltype(VRefCPU::VTop->core__DOT__ctx);

struct Context {
    Context(VTopType *_top, const ContextVType &_data)
        : top(_top), data(_data) {}

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
