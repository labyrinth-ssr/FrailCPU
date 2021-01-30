#pragma once

#include "memory.h"

#include "defs.h"
#include "cbus.h"
#include "context.h"

#include <memory>

class RefCPU : public VRefCPU {
public:
    RefCPU(size_t memory_size);

    void tick(int count = 1);

    void run();

    auto get_ctx() const -> ContextWrapper {
        return ContextWrapper(VTop, VTop->core__DOT__ctx);
    }
    auto get_ctx0() const -> ContextWrapper {
        return ContextWrapper(VTop, VTop->core__DOT__proxy__DOT__ctx0);
    }
    auto get_oreq() const -> CBusWrapper {
        return CBusWrapper(VTop, oreq);
    }
    void set_oresp(const CBusRespVType &resp) {
        oresp = resp;
    }

private:
    std::unique_ptr<Memory> mem;
};
