#pragma once

#include "common.h"
#include "bus.h"

namespace {

/**
 * static detection of suitable unsigned integer type to hold T
 */

template <size_t Width>
struct IntegerType;

template <>
struct IntegerType<1> {
    using Type = uint8_t;
};

template <>
struct IntegerType<2> {
    using Type = uint16_t;
};

template <>
struct IntegerType<4> {
    using Type = uint32_t;
};

template <>
struct IntegerType<8> {
    using Type = uint64_t;
};

/**
 * static detection of AXISize
 */

template <size_t Width>
struct MemorySize;

template <>
struct MemorySize<1> {
    static constexpr auto Size = AXISize::MSIZE1;
};

template <>
struct MemorySize<2> {
    static constexpr auto Size = AXISize::MSIZE2;
};

template <>
struct MemorySize<4> {
    static constexpr auto Size = AXISize::MSIZE4;
};

template <>
struct MemorySize<8> {
    static constexpr auto Size = AXISize::MSIZE8;
};

}

// a cell of memory stored on your cache.
template <typename T, typename Pipeline>
class MemoryCellGen {
public:
    /**
     * types & constants
     */

    using ValueType = T;

    static constexpr size_t Width = sizeof(T);
    static constexpr word_t Strobe = (1 << Width) - 1;
    static constexpr auto Size = MemorySize<Width>::Size;

    using IntType = typename IntegerType<Width>::Type;

    // supported memory widths
    static_assert(Width == 1 || Width == 2 || Width == 4);

    // delete default constructors & assignments
    MemoryCellGen() = delete;
    MemoryCellGen(const MemoryCellGen &) = delete;

    // allow move constructor & assignments
    MemoryCellGen(MemoryCellGen &&rhs) {
        init_cell(rhs.addr, rhs.p);
        rhs.addr = 0;
        rhs.p = nullptr;
    }

    auto operator=(MemoryCellGen &&rhs) {
        init_cell(rhs.addr, rhs.p);
        rhs.addr = 0;
        rhs.p = nullptr;
    }

    // construct a cell pointed to addr.
    MemoryCellGen(addr_t _addr, Pipeline *_p) {
        init_cell(_addr, _p);
        asserts(addr % Width == 0, "addr must be aligned to %d bytes", Width);
    }

    // assigned by the same type of memory cell
    auto operator=(const MemoryCellGen &rhs) {
        set(rhs.get());
    }

    // assigned by other memory cell.
    template <typename U>
    void operator=(const MemoryCellGen<U, Pipeline> &rhs) {
        using RHSType = MemoryCellGen<U, Pipeline>;

        set(reinterpret_cast<T>(static_cast<IntType>(
            reinterpret_cast<typename RHSType::IntType>(rhs.get())
        )));
    }

    // assigned by values of type T.
    auto operator=(const T &rhs) const {
        set(rhs);
    }

    // implicitly convert to type T.
    operator T() const {
        return get();
    }

    // provide std::swap.
    friend void swap(MemoryCellGen &x, MemoryCellGen &y) noexcept {
        auto u = x.get();
        auto v = y.get();
        x.set(v);
        y.set(u);
    }

    /**
     * manually get/set the value inside the cell.
     */

    auto get() const -> T {
        T value;
        p->load(addr, Size, &value, parse(addr));
        p->fence();
        return value;
    }

    void set(const T &value) const {
        auto op = parse(addr);
        p->store(addr, Size, op.strobe(), op.place(value));
    }

protected:
    template <typename TPipeline>
    friend class MemoryCellFactory;

    void init_cell(addr_t _addr, Pipeline *_p) {
        addr = _addr;
        p = _p;
    }

private:
    static constexpr auto parse = LoadOp::parse<Width>;

    addr_t addr;
    Pipeline *p;
};

template <typename Pipeline>
class MemoryCellFactory {
public:
    template <typename T>
    using MemoryCell = MemoryCellGen<T, Pipeline>;

    MemoryCellFactory(Pipeline *_p) : p(_p) {}

    template <typename T>
    auto take(addr_t addr) -> MemoryCell<T> {
        // thanks to copy elision, we can return temporary object without copying
        return MemoryCell<T>(addr, p);
    }

    template <typename T, size_t N>
    auto take(addr_t addr) -> MemoryCell<T> * {
        using Cell = MemoryCell<T>;

        uchar *buffer = new uchar[N * sizeof(Cell)];
        allocated.emplace_back(buffer);

        Cell *cells = reinterpret_cast<Cell *>(buffer);

        for (size_t i = 0; i < N; i++) {
            cells[i].init_cell(addr + i * sizeof(T), p);
        }

        return cells;
    }

private:
    Pipeline *p;

    // use std::unique_ptr<char[]> instead of std::unique_ptr<uchar> to
    // prevent mismatch of new[] and delete!
    std::vector<std::unique_ptr<uchar[]>> allocated;
};
