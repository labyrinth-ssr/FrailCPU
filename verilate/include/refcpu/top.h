#pragma once

#include "memory.h"
#include "confreg.h"
#include "diff.h"

#include "defs.h"
#include "cbus.h"
#include "context.h"

#include <memory>

class RefCPU : public VRefCPU {
public:
    RefCPU();
    ~RefCPU();

    void install_memory(const std::shared_ptr<BlockMemory> &mem);
    void start_trace(const std::string &path);
    void stop_trace();
    void start_text_trace(const std::string &path);
    void stop_text_trace();
    void open_reference_trace(const std::string &path);
    void close_reference_trace();

    void run();

private:
    std::shared_ptr<Confreg> con;
    std::shared_ptr<CBusDevice> dev;

    VerilatedFstC *tfp;
    FILE *text_tfp;
    uint64_t trace_count;
    TextDiff diff;

    auto time() -> uint64_t {
        return 10 * trace_count;
    }

    void trace_dump(uint64_t t);
    void text_trace_dump(addr_t pc, RegisterID id, word_t value);

    void _tick();
    void tick(int count = 1);

    auto get_ctx() const -> ContextWrapper {
        return ContextWrapper(VTop, VTop->core__DOT__ctx);
    }
    auto get_ctx0() const -> ContextWrapper {
        return ContextWrapper(VTop, VTop->core__DOT__ctx0);
    }
    auto get_new_ctx() const -> ContextWrapper {
        return ContextWrapper(VTop, VTop->core__DOT__proxy__DOT__new_ctx);
    }
    auto get_oreq() const -> CBusWrapper {
        return CBusWrapper(VTop, oreq);
    }
    void set_oresp(const CBusRespVType &resp) {
        oresp = resp;
    }
};
