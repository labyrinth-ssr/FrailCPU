#include "confreg.h"

void Confreg::reset() {
    mem.clear();
    mem[CR0] = 0x00000000;
    mem[CR1] = 0x00000000;
    mem[CR2] = 0x00000000;
    mem[CR3] = 0x00000000;
    mem[CR4] = 0x00000000;
    mem[CR5] = 0x00000000;
    mem[CR6] = 0x00000000;
    mem[CR7] = 0x00000000;
    mem[LED] = 0x0000ffff;
    mem[LED_RG0] = 0x00000000;
    mem[LED_RG1] = 0x00000000;
    mem[NUM] = 0x00000000;
    mem[SWITCH] = 0x000000ff;
    mem[BTN_KEY] = 0x00000000;
    mem[BTN_STEP] = 0x00000000;
    mem[SW_INTER] = 0x0000aaaa;
    mem[TIMER] = 0x00000000;
    mem[IO_SIMU] = 0x00000000;
    mem[VIRTUAL_UART] = 0x00000000;
    mem[SIMU_FLAG] = 0xffffffff;
    mem[OPEN_TRACE] = 0x00000001;
    mem[NUM_MONITOR] = 0x00000001;
}

auto Confreg::load(addr_t addr) -> word_t {
    addr &= ADDR_MASK;
    auto it = mem.find(addr);
    assert(it != mem.end());
    return it->second;
}

// NOTE: confreg ignores mask.
void Confreg::store(addr_t addr, word_t data, word_t /*mask*/) {
    addr &= ADDR_MASK;
    auto it = mem.find(addr);
    assert(it != mem.end());
    it->second = data;

    if (addr == VIRTUAL_UART)
        uart_written = true;
}

void Confreg::update() {
    uart_written = false;
    mem[TIMER]++;
}

auto Confreg::has_char() -> bool {
    return uart_written;
}

auto Confreg::get_char() -> char {
    return mem[VIRTUAL_UART] & 0xff;
}
