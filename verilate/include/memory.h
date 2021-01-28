#pragma once

#include "common.h"
#include "cbus.h"

#include <vector>
#include <string>

using ByteSeq = std::vector<uint8_t>;

auto parse_memory_file(const std::string &path) -> ByteSeq;

class MemoryImpl {
public:
    virtual void reset() = 0;
    virtual auto load(uint32_t addr) -> uint32_t = 0;
    virtual void store(uint32_t addr, uint32_t data) = 0;
    virtual void map(uint32_t addr, const ByteSeq &data) = 0;
};

class PagedMemory : public MemoryImpl {
public:
    void reset();
    auto load(uint32_t addr) -> uint32_t;
    void store(uint32_t addr, uint32_t data);
    void map(uint32_t addr, const ByteSeq &data);
};

class Memory {
public:
    Memory(MemoryImpl *_mem) : mem(_mem) {}

    void reset();
    auto eval(CBusInterface *req) -> CBusRespVType;
    void commit();

private:
    MemoryImpl *mem;
};
