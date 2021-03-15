#include "defs.h"
#include "stupid.h"

void StupidBuffer::reset() {
    dev->reset();
    clk = 0;
    resetn = 0;
    cresp = 0;
    memset(dreq, 0, sizeof(dreq));
    ticks(10);
}

void StupidBuffer::tick() {

}

void StupidBuffer::run() {

}
