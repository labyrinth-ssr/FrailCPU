#pragma once

#include "icbus.h"
#include "defs.h"

using CBusReqVType = decltype(VRefCPU::oreq);

class CBusWrapper : public ICBus {
public:
    CBusWrapper(VTopType *_top, const CBusReqVType &_req)
        : top(_top), req(_req) {}

    auto valid() -> bool {
        return top->cbus_req_t_valid(req);
    }

    auto is_write() -> bool {
        return top->cbus_req_t_is_write(req);
    }

    auto size() -> AXISize {
        return static_cast<AXISize>(top->cbus_req_t_size(req));
    }

    auto addr() -> uint32_t {
        return top->cbus_req_t_addr(req);
    }

    auto strobe() -> uint32_t {
        return top->cbus_req_t_strobe(req);
    }

    auto data() -> uint32_t {
        return top->cbus_req_t_data(req);
    }

    auto len() -> AXILength {
        return static_cast<AXILength>(top->cbus_req_t_len(req));
    }

private:
    VTopType *top;
    const CBusReqVType &req;
};
