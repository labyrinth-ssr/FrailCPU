#include "stupid.h"
#include "testbench.h"

namespace _testbench {

StupidBuffer *top;
VModelScope *scope;
DBus *dbus;

PRETEST_HOOK [] {
    top->reset();
};

WITH {
    dbus->load(0xc, MSIZE4);
    top->tick();
    assert(top->dresp == 0);
} AS("void");

WITH {
    assert(dbus->addr_ok() == true);
    assert(dbus->data_ok() == false);
    assert(dbus->rdata() == 0);
} AS("reset");

WITH {
    auto p = DBusPipeline(top, dbus);
    p.expectw(0x00000000, 0x2408ffff);
    p.fence(100);
} AS("ad hoc");

}
