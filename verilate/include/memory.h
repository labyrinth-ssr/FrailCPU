#pragma once

#include "common.h"
#include "cbus.h"

#include <vector>
#include <string>
#include <memory>

using ByteSeq = std::vector<uint8_t>;

auto parse_memory_file(const std::string &path) -> ByteSeq;

class MemoryImpl {
public:
    virtual void reset() = 0;
    virtual void map(uint32_t addr, const ByteSeq &data) = 0;
    virtual auto load(uint32_t addr) -> uint32_t = 0;
    virtual void store(uint32_t addr, uint32_t data, uint32_t mask) = 0;
};

class BlockMemory : public MemoryImpl {
public:
    BlockMemory(size_t _size, uint32_t _offset = 0);

    void reset();
    void map(uint32_t addr, const ByteSeq &data);
    auto load(uint32_t addr) -> uint32_t;
    void store(uint32_t addr, uint32_t data, uint32_t mask);

private:
    size_t size;
    uint32_t offset;
    std::vector<uint32_t> mem;
};

class Memory {
public:
    Memory(std::unique_ptr<MemoryImpl> &&_mem)
        : mem(std::move(_mem)) {}

    void reset();
    void map(uint32_t addr, const ByteSeq &data);
    auto eval(CBusInterface *req) -> CBusRespVType;
    void commit();

private:
    std::unique_ptr<MemoryImpl> mem;

    uint32_t _strobe, _data;
    struct {
        bool busy = false;
        bool is_write;

        // see "AMBA AXI Protocol Specification" (v1.0),
        // section 4.5 "Burst address".
        // we keep the original naming convention for clarity.
        uint32_t N;
        uint32_t Start_Address;
        uint32_t Number_Bytes;
        uint32_t Burst_Length;
        uint32_t Aligned_Address;
        uint32_t Wrap_Boundry;

        void reset(uint32_t ADDR, uint32_t SIZE, uint32_t LEN) {
            N = 1;
            Start_Address = ADDR;
            Number_Bytes = 1u << SIZE;  // 2^SIZE
            Burst_Length = LEN + 1;
            Aligned_Address = (Start_Address / Number_Bytes) * Number_Bytes;
            Wrap_Boundry = (Start_Address / (Number_Bytes * Burst_Length))
                * (Number_Bytes * Burst_Length);
        }

        auto Address_N() -> uint32_t {
            uint32_t _Address_N = Aligned_Address + (N - 1) * Number_Bytes;
            if (_Address_N == Wrap_Boundry + (Number_Bytes * Burst_Length))
                _Address_N = Wrap_Boundry;
            return _Address_N;
        }
    } tx, ntx;  // ntx: new transaction state
};
