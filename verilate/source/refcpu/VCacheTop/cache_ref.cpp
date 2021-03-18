#include "cache_ref.h"

void CacheRefModel::reset() {
    debug("ref: reset()\n");
}

auto CacheRefModel::load(addr_t addr, AXISize size) -> word_t {
    debug("ref: load(0x%x, %d)\n", addr, 1 << size);
    return 0;
}

void CacheRefModel::store(addr_t addr, AXISize size, word_t strobe, word_t data) {
    debug("ref: store(0x%x, %d, %x, \"%08x\")\n", addr, 1 << size, strobe, data);
}

bool CacheRefModel::check_internal() {
    debug("ref: check_internal()\n");
    return true;
}

bool CacheRefModel::check_memory() {
    debug("ref: check_memory()\n");
    return true;
}
