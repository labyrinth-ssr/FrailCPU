#include "stupid.h"
#include "testbench.h"

namespace _testbench {

StupidBuffer *top;
VModelScope *scope;
DBus *dbus;
CacheRefModel *ref;

PRETEST_HOOK [] {
    top->reset();
};

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

// both dbus->store and dbus->load wait for your model to complete
WITH {
    dbus->store(0, MSIZE4, 0b1111, 0x2048ffff);
    assert(dbus->load(0, MSIZE4) == 0x2048ffff);
} AS("synchronized");

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

WITH DEBUG CMP_TO(ref) {
    for (int i = 0; i < 32; i++) {
        dbus->store(4 * i, MSIZE4, 0b1111, 0x19260817);
        dbus->load(4 * i, MSIZE4);
    }
} AS("compare");

}
