#pragma once

#include "common.h"

// I stands for interface, not ICache
class ICacheRefModel {
public:
    virtual ~ICacheRefModel() = default;

    virtual void reset() = 0;
    virtual auto load(addr_t addr, AXISize size) -> word_t = 0;
    virtual void store(addr_t addr, AXISize size, word_t strobe, word_t data) = 0;
    virtual bool check_internal() = 0;
    virtual bool check_memory() = 0;
};
