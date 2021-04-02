#include "testbench.h"

static std::vector<ITestbench *> test_list INIT_PRIORITY(65532);
static ITestbench *current_test = nullptr;
static PretestHook pretest_hook INIT_PRIORITY(65533) = [] {};
static PosttestHook posttest_hook INIT_PRIORITY(65533) = [] {};
static std::vector<DeferHook> defer_list INIT_PRIORITY(65532);

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

static void run_test(size_t i, bool report_status = true) {
    auto t = test_list[i];

    ThreadWorker worker;
    if (report_status) {
        worker = ThreadWorker::at_interval(1000, [i, t] {
            status_line("(%zu/%zu) running \"%s\"...", i + 1, test_list.size(), t->name);
        });
    }

    t->run();
}

#include <unistd.h>
#include <sys/wait.h>

#if ICS_ON_LINUX

[[noreturn]] static void run_worker(int id, int req, int resp) {
    while (true) {
        // send a dummy char to request a task.
        asserts(write(req, "a", 1) == 1, "worker %d failed to send command", id);

        int i, read_count = read(resp, &i, sizeof(int));
        asserts(read_count >= 0, "worker %d failed to get response", id);
        if (read_count != sizeof(int))
            break;

        run_test(i, false);
    }

    exit(EXIT_SUCCESS);
}

static auto run_parallel(int n_workers) -> int {
    int count = 0, total = test_list.size(), maxfd = 0;
    std::vector<int> pid, master, worker;

    // spawn workers.
    for (int i = 0; i < n_workers; i++) {
        // pm is master->worker pipe, and pw is worker->master pipe.
        int pm[2], pw[2];
        asserts(pipe(pm) >= 0, "failed to create master pipes");
        asserts(pipe(pw) >= 0, "failed to create worker pipes");

        int p = fork();
        asserts(p >= 0, "failed to spwan workers.");

        if (p == 0) {
            close(pm[1]);
            close(pw[0]);
            run_worker(i, pw[1], pm[0]);
        } else {
            pid.push_back(p);
            close(pm[0]);
            close(pw[1]);
            master.push_back(pm[1]);
            worker.push_back(pw[0]);
            maxfd = std::max(maxfd, std::max(pm[1], pw[0]));
        }
    }

    bool failed = false;
    while (!failed && count < total) {
        fd_set set;
        FD_ZERO(&set);
        for (int fd : worker) {
            FD_SET(fd, &set);
        }

        // IO multiplexing
        int r = select(maxfd + 1, &set, NULL, NULL, NULL);
        asserts(r >= 0, "failed to fetch requests from workers");

        for (size_t j = 0; j < worker.size(); j++) {
            int fd = worker[j];
            if (FD_ISSET(fd, &set)) {
                // read the dummy char.
                char c;
                int read_count = read(fd, &c, 1);
                asserts(read_count >= 0, "failed to read response from worker");

                // the child failed and the pipe was closed,
                // so we got an EOF.
                if (read_count == 0) {
                    failed = true;
                    break;
                }

                int write_count = write(master[j], &count, sizeof(int));
                asserts(write_count == sizeof(int), "failed to send command to worker");
                count++;
            }
        }
    }

    // close all master->worker pipes, so all the workers will finally exit.
    for (int fd : master) {
        close(fd);
    }

    for (int p : pid) {
        // if some tests failed and the worker is still alive, kill it.
        if (failed && waitpid(p, NULL, WNOHANG) == 0) {
            info(YELLOW "(warn)" RESET " killing worker with pid %d...\n", p);
            kill(p, SIGKILL);
        }

        waitpid(p, NULL, 0);
    }

    if (failed)
        info(RED "FATAL!" RESET " some tests failed.\n");

    return count;
}

#endif

static auto run_serial() -> int {
    int count = 0, total = test_list.size();

    for (int i = 0; i < total; i++) {
        run_test(i);
        count++;
    }

    return count;
}

void run_testbench(int n_workers) {
#if ICS_ON_LINUX
    int count = n_workers == 1 ?
        run_serial() :
        run_parallel(n_workers);
#else
    int count = run_serial();
    (void) n_workers;
#endif

    if (count == 1)
        info(BLUE "(info)" RESET " 1 test passed.\n");
    else
        info(BLUE "(info)" RESET " %d tests passed.\n", count);
}

void abort_testbench() {
    if (current_test)
        info(RED "ERR!" RESET " testbench aborted in \"%s\"\n", current_test->name);
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

    if (result == Skipped)
        info(YELLOW "[--]" RESET " %s (skipped)\n", name);
    else
        info(GREEN "[OK]" RESET " %s\n", name);

    current_test = nullptr;
}

DeferListProxy::DeferListProxy() {
    internal_assert(defer_list.empty(), "defer list is not empty");
    defer_list.reserve(4);
}

DeferListProxy::~DeferListProxy() {
    run_defers();
    defer_list.clear();
}

void DeferListProxy::defer(const DeferHook &fn) {
    defer_list.push_back(fn);
}
