#include "testbench.h"

#include <cassert>

static std::vector<ITestbench *> test_list;
static ITestbench *current_test = nullptr;
static PretestHook pretest_hook INIT_PRIORITY(65533) = [] {};
static PosttestHook posttest_hook INIT_PRIORITY(65533) = [] {};
static std::vector<DeferHook> defer_list;

auto _testbench_pretest_hook() -> PretestHook & {
    return pretest_hook;
}

auto _testbench_posttest_hook() -> PosttestHook & {
    return posttest_hook;
}

static void run_defers() {
    // defer_list acts like a stack.
    for (auto it = defer_list.rbegin(); it != defer_list.rend(); it++) {
        (*it)();
    }
}

void run_testbench() {
    int total = 0;
    for (auto t : test_list) {
        t->run();
        total++;
    }

    info(BLUE "(info)" RESET " %d test(s) passed.\n", total);
}

void abort_testbench() {
    if (current_test)
        notify(RED "ERR!" RESET " abort in \"%s\"\n", current_test->name);
    fflush(stdout);
    fflush(stderr);
    run_defers();
}

ITestbench::ITestbench(const char *_name) : name(_name) {
    test_list.push_back(this);
}

void ITestbench::run() {
    current_test = this;
    auto result = _run(pretest_hook, posttest_hook);
    notify(GREEN "[OK]" RESET " %s", name);
    notify(result == Skipped ? " (skipped)\n" : "\n");
    current_test = nullptr;
}

DeferListProxy::DeferListProxy() {
    assert(defer_list.empty());
    defer_list.reserve(4);
}

DeferListProxy::~DeferListProxy() {
    run_defers();
    defer_list.clear();
}

void DeferListProxy::defer(const DeferHook &fn) {
    defer_list.push_back(fn);
}
