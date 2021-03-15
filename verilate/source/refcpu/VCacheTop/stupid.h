#pragma once

#include "model.h"

#include "defs.h"

class StupidBuffer : public ModelBase {
public:
    void reset();
    void tick();
    void run();

private:
    auto get_creq() const -> CBusWrapper {
        return CBusWrapper(VCacheTop, creq);
    }
};
