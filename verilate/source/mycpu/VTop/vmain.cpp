#include "runner.h"

#include "mycpu.h"

#include "confreg.h"

#include "signal.h"
#include <cstdio>
#include <iostream>
#include <stdlib.h>


ProgramRunner<MyCPU> app;

void on_error(int) {
    abort();
}

void on_abort(int) {
    app.~ProgramRunner();
}


void pb(int i)
{
    app.top->con->mem[Confreg::BTN_KEY] = 1<<(16-i);
}

void ub(int i)
{
    app.top->con->mem[Confreg::BTN_KEY] = 0x0000;
}

void finish()
{
    app.top->test_finished = true;
}
void reset()
{
    app.top->reset();

    app.top->clk = 0;
    app.top->resetn = 1;
    app.top->eval();
}
void com(int i)
{
    char c;
    fflush(stdout);
    puts("ommand:");
    std::cin>>c;
    // putchar(c);
    // puts("");
    switch (c) {
    case 'p': {
        int i;
        std::cin>>i;
        pb(i);
        printf("Push button %d\n", i);
    } break;
    case 'u': {
        ub(1);
        printf("Pop button\n");
    } break;
    case 'r': {
        reset();
    } break;
    }
    if (c == 'q') {
        finish();
    }
}


int vmain(int argc, char *argv[]) {
    hook_signal(SIGABRT, on_abort);
    hook_signal(SIGINT, com);

    return app.main(argc, argv);
}
