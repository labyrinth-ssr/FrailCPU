#pragma once

#include "common.h"

using CBusRespVType = uint64_t;

enum class AXISize {
    MSIZE1 = 0,
    MSIZE2 = 1,
    MSIZE4 = 2,
    MSIZE8 = 3,
};

enum class AXILength {
    MLEN1  = 0b0000,
    MLEN2  = 0b0001,
    MLEN4  = 0b0011,
    MLEN8  = 0b0111,
    MLEN16 = 0b1111,
};

/**
 * this pure-virtual class should be inherited and
 * implemented by each verilated model.
 */
class CBus {
public:
    static constexpr auto make_response(
        bool ready, bool last, word_t data
    ) -> CBusRespVType {
        return data | (uint64_t(ready) << 33) | (uint64_t(last) << 32);
    }

    virtual ~CBus() = default;

    virtual auto valid() const -> bool = 0;
    virtual auto is_write() const -> bool = 0;
    virtual auto size() const -> AXISize = 0;
    virtual auto addr() const -> word_t = 0;
    virtual auto strobe() const -> word_t = 0;
    virtual auto data() const -> word_t = 0;
    virtual auto len() const -> AXILength = 0;
};

/**
 * a helper class/generator for CBusWrapper
 */
template <typename CBusReqVType, typename VTopType>
class CBusWrapperGen : public CBus {
public:
    CBusWrapperGen(VTopType *_top, const CBusReqVType &_req)
        : top(_top), req(_req) {}

    auto valid() const -> bool {
        return top->cbus_req_t_valid(req);
    }
    auto is_write() const -> bool {
        return top->cbus_req_t_is_write(req);
    }
    auto size() const -> AXISize {
        return static_cast<AXISize>(top->cbus_req_t_size(req));
    }
    auto addr() const -> addr_t {
        return top->cbus_req_t_addr(req);
    }
    auto strobe() const -> word_t {
        return top->cbus_req_t_strobe(req);
    }
    auto data() const -> word_t {
        return top->cbus_req_t_data(req);
    }
    auto len() const -> AXILength {
        return static_cast<AXILength>(top->cbus_req_t_len(req));
    }

private:
    VTopType *top;
    const CBusReqVType &req;
};
