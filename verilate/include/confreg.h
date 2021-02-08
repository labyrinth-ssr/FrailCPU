#pragma once

#include "memory.h"

#include <unordered_map>

/**
 * simulate the "confreg.v" from NSCSCC
 */

class Confreg : public IMemory {
public:
    static constexpr addr_t ADDR_MASK = 0xffff;

    enum Layout : addr_t {
        CR0 = 0x8000,
        CR1 = 0x8004,
        CR2 = 0x8008,
        CR3 = 0x800c,
        CR4 = 0x8010,
        CR5 = 0x8014,
        CR6 = 0x8018,
        CR7 = 0x801c,
        LED = 0xf000,
        LED_RG0 = 0xf004,
        LED_RG1 = 0xf008,
        NUM = 0xf010,
        SWITCH = 0xf020,
        BTN_KEY = 0xf024,
        BTN_STEP = 0xf028,
        SW_INTER = 0xf02c,
        TIMER = 0xe000,
        IO_SIMU = 0xffec,
        VIRTUAL_UART = 0xfff0,
        SIMU_FLAG = 0xfff4,
        OPEN_TRACE = 0xfff8,
        NUM_MONITOR = 0xfffc,
    };

    void reset();
    auto load(addr_t addr) -> word_t;
    void store(addr_t addr, word_t data, word_t mask);

    void update();
    auto has_char() -> bool;
    auto get_char() -> char;

private:
    bool uart_written;
    std::unordered_map<addr_t, word_t> mem;
};
