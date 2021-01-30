#include "common.h"
#include "memory.h"

#include <cassert>
#include <cstring>
#include <algorithm>

constexpr uint32_t _MASK_TABLE[] = {
    0x00000000, 0x000000ff, 0x0000ff00, 0x0000ffff,
    0x00ff0000, 0x00ff00ff, 0x00ffff00, 0x00ffffff,
    0xff000000, 0xff0000ff, 0xff00ff00, 0xff00ffff,
    0xffff0000, 0xffff00ff, 0xffffff00, 0xffffffff,
};

BlockMemory::BlockMemory(size_t _size, uint32_t _offset)
    : size(_size), offset(_offset) {
    assert(size % 4 == 0);
    mem.resize(size / 4);
    reset();
}

void BlockMemory::reset() {
    fill(mem.begin(), mem.end(), 0);
}

void BlockMemory::map(uint32_t addr, const ByteSeq &data) {
    addr -= offset;
    assert(addr + data.size() <= size);

    for (size_t i = 0; i < data.size(); i++) {
        size_t index = (addr + i) / 4;
        uint32_t shamt = (addr + i) % 4 * 8;
        uint32_t mask = ~(0xffu << shamt);

        uint32_t &value = mem[index];
        value = (value & mask) | (uint32_t(data[i]) << shamt);
    }
}

auto BlockMemory::load(uint32_t addr) -> uint32_t {
    uint32_t caddr = addr;
    addr -= offset;
    assert(addr < size);

    size_t index = addr / 4;  // align to 4 bytes
    uint32_t value = mem[index];

    info("mem[%08x] -> %08x\n", caddr, value);

    return value;
}

void BlockMemory::store(uint32_t addr, uint32_t data, uint32_t mask) {
    uint32_t caddr = addr;
    addr -= offset;
    assert(addr < size);

    size_t index = addr / 4;  // align to 4 bytes
    uint32_t &value = mem[index];
    value = (value & ~mask) | (data & mask);

    info("mem[%08x] <- %08x\n", caddr, value);
}

void Memory::reset() {
    mem->reset();
    tx.reset();
    ntx.reset();
    _strobe = _data = 0;
}

void Memory::map(uint32_t addr, const ByteSeq &data) {
    mem->map(addr, data);
}

auto Memory::eval_resp() -> CBusRespVType {
    if (tx.busy) {
        // fetch data if needed
        uint32_t data = 0;
        if (!tx.is_write) {
            uint32_t addr = tx.Address_N();
            data = mem->load(addr);
        }

        // return response
        return ICBus::make_response(true, tx.last(), data);
    } else
        return 0;
}

void Memory::eval_req(const ICBus &req) {
    if (tx.busy) {
        // simple sanity checks
        assert(req.valid());
        assert(req.is_write() == tx.is_write);
        assert(req.addr() == tx.Start_Address);

        // pass arguments to commit
        _strobe = req.strobe();
        _data = req.data();

        // evaluate next transaction state
        if (tx.last())
            ntx.reset();
        else
            ntx.N++;
    } else if (req.valid()) {
        // no transaction in progress, so we kick off a new one.
        ntx.init_axi(
            req.addr(),
            static_cast<uint32_t>(req.size()),
            static_cast<uint32_t>(req.len())
        );
        ntx.busy = true;
        ntx.is_write = req.is_write();
    }
}

void Memory::commit() {
    if (tx.busy && tx.is_write) {
        // perform write operation if needed
        uint32_t addr = tx.Address_N();
        uint32_t mask = _MASK_TABLE[_strobe];
        mem->store(addr, _data, mask);
        _strobe = _data = 0;
    }

    tx = ntx;
}
