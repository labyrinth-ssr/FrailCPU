#pragma once

#include "model.h"
#include "bus.h"

#include "defs.h"

class MyCPU final : public ModelBase {
public:
    MyCPU() :
        current_cycle(0),
        test_finished(false) {}

    void reset();
    void tick();
    void run();
bool test_finished;
private:
    int current_cycle;
    

    auto get_oreq() const -> CBusWrapper {
        return CBusWrapper(VTop, oreq);
    }

    auto get_writeback_pc1() const -> addr_t;
    auto get_writeback_pc2() const -> addr_t;
    auto get_writeback_id1() const -> int;
    auto get_writeback_id2() const -> int;
    auto get_writeback_value1() const -> word_t;
    auto get_writeback_value2() const -> word_t;
    auto get_writeback_wen1() const -> word_t;
    auto get_writeback_wen2() const -> word_t;

    void print_status();
    void print_writeback();
};
