#include "common.h"
#include "memory.h"

#include <cassert>
#include <cstring>
#include <algorithm>

auto MemoryRouter::search(addr_t addr) -> IMemory* {
    for (auto &e : entries) {
        if ((addr & e.mask) == e.prefix)
            return e.mem.get();
    }
    return nullptr;
}

void MemoryRouter::reset() {
    for (auto &e : entries) {
        e.mem->reset();
    }
}

auto MemoryRouter::load(addr_t addr) -> word_t {
    auto mem = search(addr);
    assert(mem);
    return mem->load(addr);
}

void MemoryRouter::store(addr_t addr, word_t data, word_t mask) {
    auto mem = search(addr);
    assert(mem);
    mem->store(addr, data, mask);
}

BlockMemory::BlockMemory(size_t _size, addr_t _offset)
    : size(_size), offset(_offset) {
    assert(size % 4 == 0);
    mem.resize(size / 4);
    saved_mem = mem;
}

BlockMemory::BlockMemory(const ByteSeq &data, addr_t _offset)
    : BlockMemory(data.size(), _offset) {
    map(offset, data);
    saved_mem = mem;
}

void BlockMemory::reset() {
    mem = saved_mem;
}

void BlockMemory::map(addr_t addr, const ByteSeq &data) {
    addr -= offset;
    assert(addr + data.size() <= size);

    for (size_t i = 0; i < data.size(); i++) {
        size_t index = (addr + i) / 4;
        word_t shamt = (addr + i) % 4 * 8;
        word_t mask = ~(0xffu << shamt);

        word_t &value = mem[index];
        value = (value & mask) | (word_t(data[i]) << shamt);
    }
}

auto BlockMemory::load(addr_t addr) -> word_t {
    addr_t caddr = addr;
    addr -= offset;
    assert(addr < size);

    size_t index = addr / 4;  // align to 4 bytes
    word_t value = mem[index];

    info("mem[%08x] -> %08x\n", caddr, value);

    return value;
}

void BlockMemory::store(addr_t addr, word_t data, word_t mask) {
    addr_t caddr = addr;
    addr -= offset;
    assert(addr < size);

    size_t index = addr / 4;  // align to 4 bytes
    word_t &value = mem[index];
    value = (value & ~mask) | (data & mask);

    info("mem[%08x] <- %08x\n", caddr, value);
}
