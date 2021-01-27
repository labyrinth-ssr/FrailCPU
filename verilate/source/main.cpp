#include <cstdio>

#include "verilated.h"

extern void vmain(int argc, char *argv[]);

int main(int argc, char *argv[]) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    vmain(argc, argv);

    return 0;
}
