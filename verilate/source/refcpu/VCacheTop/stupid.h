#pragma once

#include "model.h"

#include "defs.h"

class StupidBuffer final : public ModelBase {
public:
    void reset();
    void tick();
    void run();

private:
    uint64_t tickcount = 0;

    auto get_creq() const -> CBusWrapper {
        return CBusWrapper(VCacheTop, creq);
    }

    // template is used to reduce the number of unnecessary branches.
    // hope compilers optimizes those "if"s out.
    template <bool Memory = true, bool Trace = true>
    void _tick() {
        // see refcpu/VTop/refcpu.cpp for the descriptions of each stage.

        tickcount++;
        clk = 0;

        if (Memory)
            cresp = (CBusRespVType) dev->eval_resp();

        eval();

        if (Trace)
            fst_dump(+1);
        if (Memory)
            dev->eval_req(get_creq());

        clk = 1;

        if (Memory)
            dev->sync();

        eval();

        if (Trace) {
            fst_advance();
            fst_dump(+0);
        }
    }
};

using DBus = DBusGen<StupidBuffer, VModelScope>;

namespace _testbench {
    extern StupidBuffer *top;
    extern VModelScope *scope;
    extern DBus *dbus;
}

#include <queue>

class DBusPipeline {
public:
    enum class LoadOp {
        DISCARD,
        SIZE1_SHT0,
        SIZE1_SHT8,
        SIZE1_SHT16,
        SIZE1_SHT24,
        SIZE2_SHT0,
        SIZE2_SHT16,
        SIZE4_SHT0
    };

    DBusPipeline(StupidBuffer *_top, DBus *_dbus)
        : top(_top), dbus(_dbus) {
        assert(!busy());
    }

    bool busy() const {
        return dbus->valid();
    }

    bool empty() const {
        return pending.empty() && ongoing.empty();
    }

    void tick() {
        // we should read the signals before tick!
        bool valid = busy();
        bool addr_ok = dbus->addr_ok();
        bool data_ok = dbus->data_ok();
        auto data = dbus->rdata();

        top->tick();

        if (addr_ok && valid) {
            assert(!pending.empty());
            ongoing.push(pending.front());
            pending.pop();
        }

        // data may be returned in one cycle
        if (data_ok) {
            assert(!ongoing.empty());

            auto u = ongoing.front();
            ongoing.pop();

            debug(
                "pipeline: %s \"%08x\" @0x%x → got \"%08x\" (msize=%d, strobe=0x%x)\n",
                u.is_load() ? (u.dest ? "load" : "expect") : "store",
                u.data, u.addr, data,
                u.size, u.strobe
            );

            if (u.dest)  // it must be a load
                u.apply_load(data);
            else if (u.is_load())  // since u.dest is NULL, it must be an assertion
                u.apply_assert(data);
        }

        if (pending.empty())
            dbus->clear();
        else
            issue(pending.front());
    }

    /**
     * raw load/strore interface
     * we don't recommend you use these functions.
     */

    void load(addr_t addr, AXISize size, void *dest, LoadOp op = LoadOp::SIZE4_SHT0) {
        if (!dest)
            op = LoadOp::DISCARD;
        submit(Task(addr, size, dest, op));
    }
    void store(addr_t addr, AXISize size, word_t strobe, word_t data) {
        submit(Task(addr, size, strobe, data));
    }
    void expect(addr_t addr, AXISize size, word_t data, LoadOp op = LoadOp::SIZE4_SHT0) {
        submit(Task(addr, size, data, op));
    }

    /**
     * helper functions which handle data placement correctly.
     */

    void loadw(addr_t addr, void *dest) {
        assert((addr & 0x3) == 0);
        load(addr, MSIZE4, dest, LoadOp::SIZE4_SHT0);
    }
    void loadh(addr_t addr, void *dest) {
        assert((addr & 0x1) == 0);
        load(addr, MSIZE2, dest, parse_op<2>(addr));
    }
    void loadb(addr_t addr, void *dest) {
        load(addr, MSIZE1, dest, parse_op<1>(addr));
    }

    void storew(addr_t addr, word_t data) {
        assert((addr & 0x3) == 0);
        store(addr, MSIZE4, 0b1111u, data);
    }
    void storeh(addr_t addr, word_t data) {
        assert((addr & 0x1) == 0);
        word_t strobe, value;
        std::tie(strobe, value) = parse_addr<0b0011u>(addr, data);
        store(addr, MSIZE2, strobe, value);
    }
    void storeb(addr_t addr, word_t data) {
        word_t strobe, value;
        std::tie(strobe, value) = parse_addr<0b0001u>(addr, data);
        store(addr, MSIZE1, strobe, value);
    }

    void expectw(addr_t addr, word_t data) {
        assert((addr & 0x3) == 0);
        expect(addr, MSIZE4, data, LoadOp::SIZE4_SHT0);
    }
    void expecth(addr_t addr, word_t data) {
        assert((addr & 0x1) == 0);
        word_t _, value;
        std::tie(_, value) = parse_addr<0b0011u>(addr, data);
        expect(addr, MSIZE2, value, parse_op<2>(addr));
    }
    void expectb(addr_t addr, word_t data) {
        word_t _, value;
        std::tie(_, value) = parse_addr<0b0001u>(addr, data);
        expect(addr, MSIZE1, value, parse_op<1>(addr));
    }

    // wait for all pending and ongoing requests to finish.
    // max_count is the maximum number of ticks
    void fence(uint64_t max_count = UINT64_MAX) {
        uint64_t count = 0;
        while (!empty() && count < max_count) {
            tick();
            count++;
        }

        assert(empty());
    }

private:
    struct Task {
        Task(addr_t _addr, AXISize _size, void *_dest, LoadOp _op)
            : addr(_addr), size(_size), data(0), strobe(0),
              dest(_dest), load_op(_op) {}
        Task(addr_t _addr, AXISize _size, word_t _strobe, word_t _data)
            : addr(_addr), size(_size), data(_data), strobe(_strobe),
              dest(nullptr), load_op(LoadOp::SIZE4_SHT0) {}
        Task(addr_t _addr, AXISize _size, word_t _data, LoadOp _op)
            : addr(_addr), size(_size), data(_data), strobe(0),
              dest(nullptr), load_op(_op) {}

        addr_t addr;
        AXISize size;
        word_t data;
        word_t strobe;
        void *dest;
        LoadOp load_op;

        bool is_load() const {
            return !strobe;
        }

        void apply_assert(word_t value) {
            word_t mask;
            switch (load_op) {
                case LoadOp::SIZE4_SHT0:  mask = 0xffffffff; break;
                case LoadOp::SIZE2_SHT16: mask = 0xffff0000; break;
                case LoadOp::SIZE2_SHT0:  mask = 0x0000ffff; break;
                case LoadOp::SIZE1_SHT24: mask = 0xff000000; break;
                case LoadOp::SIZE1_SHT16: mask = 0x00ff0000; break;
                case LoadOp::SIZE1_SHT8:  mask = 0x0000ff00; break;
                case LoadOp::SIZE1_SHT0:  mask = 0x000000ff; break;
                case LoadOp::DISCARD:     mask = 0x00000000; break;
            }
            assert(((data ^ value) & mask) == 0);
        }

        void apply_load(word_t value) {
            switch (load_op) {
                case LoadOp::SIZE4_SHT0:
                    *static_cast<uint32_t *>(dest) = value;
                    break;

                case LoadOp::SIZE2_SHT16:
                    value >>= 16;
                case LoadOp::SIZE2_SHT0:
                    *static_cast<uint16_t *>(dest) = value;
                    break;

                case LoadOp::SIZE1_SHT24:
                    *static_cast<uint8_t *>(dest) = value >> 24;
                    break;
                case LoadOp::SIZE1_SHT16:
                    *static_cast<uint8_t *>(dest) = value >> 16;
                    break;
                case LoadOp::SIZE1_SHT8:
                    value >>= 8;
                case LoadOp::SIZE1_SHT0:
                    *static_cast<uint8_t *>(dest) = value;
                    break;

                case LoadOp::DISCARD: break;
            }
        }
    };

    StupidBuffer *top;
    DBus *dbus;
    std::queue<Task> pending, ongoing;

    void issue(const Task &t) {
        if (t.is_load())
            dbus->async_load(t.addr, t.size);
        else
            dbus->async_store(t.addr, t.size, t.strobe, t.data);
    }

    void submit(const Task &t) {
        pending.push(t);
        if (!busy())
            issue(t);
    }

    template <word_t Strobe>
    static auto parse_addr(addr_t addr, word_t data) -> std::tuple<word_t, word_t> {
        int shamt = addr & 0x3;
        word_t strobe = Strobe << shamt;
        word_t value = data << (shamt << 3);
        return std::make_tuple(strobe, value);
    }

    template <int Width>
    static auto parse_op(addr_t addr) -> LoadOp {
        static_assert(Width == 1 || Width == 2 || Width == 4);

        if (Width == 4)
            return LoadOp::SIZE4_SHT0;
        if (Width == 2)
            return addr & 0x2 ? LoadOp::SIZE2_SHT16 : LoadOp::SIZE2_SHT0;
        if (Width == 1) {
            switch (addr & 0x3) {
                default:
                case 0b00: return LoadOp::SIZE1_SHT0;
                case 0b01: return LoadOp::SIZE1_SHT8;
                case 0b10: return LoadOp::SIZE1_SHT16;
                case 0b11: return LoadOp::SIZE1_SHT24;
            }
        }
    }
};
