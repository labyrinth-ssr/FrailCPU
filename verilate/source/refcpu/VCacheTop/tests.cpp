#include "stupid.h"
#include "testbench.h"


StupidBuffer *top;

PRETEST_HOOK [] {
    top->reset();
};

WITH {
    assert(top->dresp == 0);
} AS("void");
