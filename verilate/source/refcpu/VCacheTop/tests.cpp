#include "common.h"
#include "testbench.h"

#include "stupid.h"

namespace _testbench {

StupidBuffer *top;
VModelScope *scope;
DBus *dbus;
CacheRefModel *ref;

PRETEST_HOOK [] {
    top->reset();
};

/**
 * basic tests
 */

WITH {
    dbus->async_load(0xc, MSIZE4);
    top->tick();
    // assert(top->dresp == 0);
} AS("void");

WITH {
    assert(dbus->addr_ok() == true);
    assert(dbus->data_ok() == false);
    assert(dbus->rdata() == 0);
} AS("reset");

WITH {
    for (int i = 0; i < 4096; i++) {
        dbus->async_loadw(4 * i);
        dbus->clear();
        top->eval();

        for (int j = 0; j < 256; j++) {
            assert(!dbus->valid());
            top->tick();
        }
    }
} AS("fake load");

WITH {
    for (int i = 0; i < 4096; i++) {
        dbus->async_storew(4 * i, 0xdeadbeef);
        dbus->clear();
        top->eval();

        for (int j = 0; j < 256; j++) {
            assert(!dbus->valid());
            top->tick();
        }
    }
} AS("fake store");

// both dbus->store and dbus->load wait for your model to complete
WITH {
    dbus->store(0, MSIZE4, 0b1111, 0x2048ffff);
    assert(dbus->load(0, MSIZE4) == 0x2048ffff);
} AS("synchronized");

WITH {
    // S iterates over 0b0000 to 0b1111.
    std::vector<word_t> a;  // to store the correct value
    a.resize(16);

    for (int S = 0; S < 16; S++) {
        auto value = randi();  // equivalent to randi<word_t>, returns a 32 bit random unsigned integer.
        dbus->store(0x100 + 4 * S, MSIZE4, S, value);
        a[S] = value & STROBE_TO_MASK[S];  // STROBE_TO_MASK is defined in common.h
    }

    for (int i = 0; i < 16; i++) {
        auto got = dbus->load(0x100 + 4 * i, MSIZE4);
        assert(got == a[i]);
    }
} AS("strobe");

// this is an example of DBusPipeline.
// all operations performed by pipeline are asynchronous, unless
// p.fence() is called.
// add DEBUG to see all memory & pipeline operations.
WITH TRACE /*DEBUG*/ {
    auto p = DBusPipeline(top, dbus);

    {
        word_t value;
        p.store(0xc, MSIZE4, 0b1111, 0x12345678);
        p.load(0xc, MSIZE4, &value);
        p.expect(0xc, MSIZE4, 0x12345678);
        p.fence(128);
        assert(value == 0x12345678);
    }

    {
        uint8_t a[4];
        uint16_t b[2];
        uint32_t c;
        p.storew(0x108, 0xdeadbeef);
        p.storeh(0x100, 0x0817);
        p.storeh(0x102, 0x1926);
        p.storeb(0x104, 0xdd);
        p.storeb(0x105, 0xcc);
        p.storeb(0x106, 0xbb);
        p.storeb(0x107, 0xaa);
        p.loadb(0x108, a + 0);
        p.loadb(0x109, a + 1);
        p.loadb(0x10a, a + 2);
        p.loadb(0x10b, a + 3);
        p.loadh(0x104, b + 0);
        p.loadh(0x106, b + 1);
        p.loadw(0x100, &c);
        p.expectb(0x100, 0x17);
        p.expectb(0x101, 0x08);
        p.expectb(0x102, 0x26);
        p.expectb(0x103, 0x19);
        p.expecth(0x108, 0xbeef);
        p.expecth(0x10a, 0xdead);
        p.expectw(0x104, 0xaabbccdd);
        p.fence(2048);
        assert(a[0] == 0xef && a[1] == 0xbe && a[2] == 0xad && a[3] == 0xde);
        assert(b[0] == 0xccdd && b[1] == 0xaabb);
        assert(c == 0x19260817);
    }

    p.fence(0);  // assert that pipeline is empty now
    p.fence();  // must not block

    {
        // NOTE: the default memory size is 1 MiB
        //       which is specified in common.h: "MEMORY_SIZE".
        //       Therefore, the maximum address is 0xfffff.

        word_t value;
        p.storew(0xff000, 0x2048ffff);
        p.loadw(0xff000, &value);

        // manually update the pipeline
        for (int i = 0; i < 128; i++) {
            p.tick();
        }

        assert(value == 0x2048ffff);
    }

    p.fence(0);
} AS("ad hoc");

// this test is explicitly marked with "SKIP".
WITH SKIP {
    // you should not fail here since it's skipped.
    bool one = 1, three = 3;
    assert(one + one == three);  // trust me, it must fail
} AS("akarin!");

/**
 * model comparing
 *
 * you can use synchronous load/store functions in dbus.
 * we have hacked these functions to check the results with your
 * reference model during invocation.
 */

constexpr size_t CMP_SCAN_SIZE = 32 * 1024;  // 32 KiB

WITH CMP_TO(ref) {
    for (size_t i = 0; i < CMP_SCAN_SIZE / 4; i++) {
        dbus->storew(4 * i, randi<uint32_t>());
        dbus->loadw(4 * i);
    }
} AS("cmp: word");

WITH CMP_TO(ref) {
    for (size_t i = 0; i < CMP_SCAN_SIZE / 2; i++) {
        dbus->storeh(2 * i, randi<uint16_t>());
        dbus->loadh(2 * i);
    }
} AS("cmp: halfword");

WITH CMP_TO(ref) {
    for (size_t i = 0; i < CMP_SCAN_SIZE; i++) {
        dbus->storeb(i, randi<uint8_t>());
        dbus->loadh(i);
    }
} AS("cmp: byte");

WITH CMP_TO(ref) {
    constexpr int T = 65536;
    for (int i = 0; i < T; i++) {
        addr_t addr = randi<addr_t>(0, MEMORY_SIZE / 8) * 4;  // random address within 512 KiB region
        dbus->storew(addr, randi());
        dbus->loadw(addr);
    }
} AS("cmp: random");

/**
 * pressure tests or benchmarks
 */

WITH {
    auto p = DBusPipeline(top, dbus);

    for (addr_t i = 0; i < MEMORY_SIZE / 4; i++) {
        p.storew(4 * i, 0xcccccccc);
    }
    for (addr_t i = 0; i < MEMORY_SIZE / 4; i++) {
        p.expectw(4 * i, 0xcccccccc);
    }
    p.fence();
} AS("memset");

}
