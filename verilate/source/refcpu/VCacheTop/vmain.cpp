#include "runner.h"

#include "stupid.h"

ProgramRunner<StupidBuffer> app;

void on_error(int) {
    app.~ProgramRunner();
}

int vmain(int argc, char *argv[]) {
    hook_signal(SIGABRT, on_error);
    hook_signal(SIGINT, on_error);
    app.no_init_memory();
    app.no_init_text_trace();
    return app.main(argc, argv);
}
