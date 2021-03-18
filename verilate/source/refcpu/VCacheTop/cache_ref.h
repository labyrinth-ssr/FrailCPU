#pragma once

#include "reference.h"

class CacheRefModel final : public ICacheRefModel {
public:
    void reset();
    auto load(addr_t addr, AXISize size) -> word_t;
    void store(addr_t addr, AXISize size, word_t strobe, word_t data);
    bool check_internal();
    bool check_memory();
};
