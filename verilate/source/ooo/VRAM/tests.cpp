#include "common.h"
#include "testbench.h"

#include "ram.h"

#define check(i, expected) \
    ASSERT(top->get_r(i) == (expected));

namespace _testbench {

RAM *top;

PRETEST_HOOK [] {
    top->reset();
};

WITH {
    check(0, 0x0);
    check(1, 0x0);
    check(2, 0x0);
} AS("reset 1");

WITH {
    top->set_w(0, true, 0, 0x1234);
    top->set_r(2, 1);
    top->tick();
    check(0, 0x1234);
    check(1, 0x1234);
    check(2, 0x0);
} AS("simple write");

WITH {
    check(0, 0x0);
    check(1, 0x0);
    check(2, 0x0);
} AS("reset 2");

WITH {
    top->set_w(0, false, 0, 0xabcd);
    top->set_w(1, false, 1, 0xabcd);
    top->set_w(2, false, 2, 0xabcd);
    top->set_r(1, 1);
    top->set_r(2, 2);
    top->tick();
    check(0, 0x0);
    check(1, 0x0);
    check(2, 0x0);
} AS("fake write");

WITH {
    top->set_w(0, true, 0, 0x2333);
    top->set_r(1, 1);
    top->eval();
    check(0, 0x0);
    check(1, 0x0);
    check(2, 0x0);

    top->tick();
    check(0, 0x2333);
    check(1, 0x0);
    check(2, 0x2333);

    top->set_w(0, false, 0, 0x0);
    top->eval();
    check(0, 0x2333);
    check(1, 0x0);
    check(2, 0x2333);

    top->set_r(2, 2);
    top->eval();
    check(0, 0x2333);
    check(1, 0x0);
    check(2, 0x2333);

    top->tick();
    check(0, 0x2333);
    check(1, 0x0);
    check(2, 0x0);
} AS("synchronous");

WITH {
    top->set_w(0, true, 0, 0x1111);
    top->set_w(1, true, 0, 0x2222);
    top->set_w(2, true, 0, 0x3333);
    top->tick();
    check(0, 0x3333);
    check(1, 0x3333);
    check(2, 0x3333);

    top->set_w(0, true, 0, 0x4444);
    top->set_w(1, true, 0, 0x5555);
    top->set_w(2, false, 0, 0x6666);
    top->tick();
    check(0, 0x5555);
    check(1, 0x5555);
    check(2, 0x5555);

    top->set_w(0, true, 0, 0x7777);
    top->set_w(1, false, 0, 0x8888);
    top->set_w(2, false, 0, 0x9999);
    top->tick();
    check(0, 0x7777);
    check(1, 0x7777);
    check(2, 0x7777);

    top->set_w(0, true, 0, 0xaaaa);
    top->set_w(1, false, 0, 0xbbbb);
    top->set_w(2, true, 0, 0xcccc);
    top->tick();
    check(0, 0xcccc);
    check(1, 0xcccc);
    check(2, 0xcccc);

    top->set_r(1, 1);
    top->set_r(2, 2);
    top->set_w(0, true, 0, 0xdddd);
    top->set_w(1, true, 1, 0xeeee);
    top->set_w(2, true, 1, 0xffff);
    top->tick();
    check(0, 0xdddd);
    check(1, 0xffff);
    check(2, 0x0000);
} AS("priority");

WITH {
    for (int i = 0; i < N_WRITE; i++) {
        for (int j = 0; j < DEPTH; j++) {
            for (int k = 0; k < N_READ; k++) {
                top->set_r(k, j);
            }

            word_t v = randi() & 0xffff;

            top->set_w(i, true, j, v);
            top->tick();
            for (int k = 0; k < N_READ; k++) {
                check(k, v);
            }

            top->set_w(i, false, j, 0);
            top->tick();
            for (int k = 0; k < N_READ; k++) {
                check(k, v);
            }
        }
    }
} AS("scan");

WITH {
    constexpr int T = 500000;

    std::vector<word_t> ref;
    ref.resize(DEPTH);

    for (int t = 0; t < T; t++) {
        int a = randi(0, DEPTH - 1);
        word_t v = randi() & 0xffff;
        ref[a] = v;
        top->set_w(0, true, a, v);

        a = randi(0, DEPTH - 1);
        v = randi() & 0xffff;
        ref[a] = v;
        top->set_w(1, true, a, v);

        a = randi(0, DEPTH - 1);
        v = randi() & 0xffff;
        ref[a] = v;
        top->set_w(2, true, a, v);

        int r1 = randi(0, DEPTH - 1);
        top->set_r(0, r1);

        int r2 = randi(0, DEPTH - 1);
        top->set_r(1, r2);

        int r3 = randi(0, DEPTH - 1);
        top->set_r(2, r3);

        top->tick();

        check(0, ref[r1]);
        check(1, ref[r2]);
        check(2, ref[r3]);
    }
} AS("random read/write");

}
