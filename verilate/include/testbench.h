#pragma once

#include "common.h"

#include <cassert>

#include <vector>
#include <functional>

enum TestbenchStatus {
    Finished,
    Skipped
};

using PretestHook = std::function<void(void)>;
using PosttestHook = std::function<void(void)>;
using DeferHook = std::function<void(void)>;

auto _testbench_pretest_hook() -> PretestHook &;
auto _testbench_posttest_hook() -> PosttestHook &;

void run_testbench();
void abort_testbench();

class ITestbench {
public:
    ITestbench(const char *_name);

    const char *name;

    void run();

private:
    // returns true if test has been skipped.
    virtual auto _run(
        const PretestHook &pre_fn, const PosttestHook &post_fn
    ) -> TestbenchStatus = 0;
};

// the local defer list
class DeferListProxy {
public:
    DeferListProxy();
    ~DeferListProxy();

    void defer(const DeferHook &fn);
};

/**
 * helper macros to setup global pre-test and post-test hooks.
 *
 * usage:
 * PRETEST_HOOK/POSTTEST_HOOK <lambda-expression>;
 *
 * examples:
 *
 * PRETEST_HOOK [] {
 *     dev->reset();
 * };
 * POSTTEST_HOOK [] {
 *     // source code here.
 * };
 */

#define PRETEST_HOOK \
    static struct _TestbenchPretestHookSetter { \
        _TestbenchPretestHookSetter(const PretestHook &fn) { \
            _testbench_pretest_hook() = fn; \
        } \
    } _testbench_pretest_hook_setter_inst \
        INIT_PRIORITY(65534) = (PretestHook)
#define POSTTEST_HOOK \
    static struct _TestbenchPosttestHookSetter { \
        _TestbenchPosttestHookSetter(const PosttestHook &fn) { \
            _testbench_posttest_hook() = fn; \
        } \
    } _testbench_posttest_hook_setter_inst \
        INIT_PRIORITY(65534) = (PosttestHook)

/**
 * unit test declaration macros
 *
 * usage:
 * WITH [plugins...] { <source code> } AS("<name>");
 *
 * example:
 *
 * WITH LOG {
 *     // source code here
 * } AS("test name");
 */

// unique id magic: https://stackoverflow.com/a/2419720/7434327
#define _TESTBENCH_CAT_IMPL(x, y) x##y
#define _TESTBENCH_CAT(x, y) _TESTBENCH_CAT_IMPL(x, y)
#define _TESTBENCH_UNIQUE_NAME(x) _TESTBENCH_CAT(x, __LINE__)

#define _TESTBENCH_BEGIN(id) \
    static class id final : public ITestbench { \
        using ITestbench::ITestbench; \
        auto _run( \
            const PretestHook &pre_fn, const PosttestHook &post_fn \
        ) -> TestbenchStatus { \
            pre_fn(); \
            { \
                DeferListProxy _; \
                _.defer(post_fn); \
                {
#define _TESTBENCH_END(id, name) \
                } \
            } \
            return Finished; \
        } \
    } id INIT_PRIORITY(65535) (name);

#define WITH _TESTBENCH_BEGIN(_TESTBENCH_UNIQUE_NAME(_Testbench_L))
#define AS(name) _TESTBENCH_END(_TESTBENCH_UNIQUE_NAME(_testbench_L), name)

/**
 * basic plugins
 */

#define TOP_RESET { top->reset(); }

#ifdef TESTBENCH_RUN_ALL
#define SKIP /* no effect */
#else
#define SKIP { return Skipped; }
#endif

#define ENABLE_WITH_FN(controller, fn) { \
    controller(true); \
    fn(); \
    _.defer([] { \
        controller(false); \
    }); \
}
#define ENABLE(controller) ENABLE_WITH_FN(controller, [] {})

#define LOG ENABLE(enable_logging)
#define DEBUG ENABLE(enable_debugging)
#define STATUS ENABLE(enable_status_line)
#define TRACE ENABLE_WITH_FN(top->enable_fst_trace, top->reset)
