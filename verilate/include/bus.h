#pragma once

#include "common.h"

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
 * cache bus (CBus)
 */

using CBusReqVType = uint32_t[3];  // 77 bits
using CBusRespVType = uint64_t;  // 34 bits

struct CBusReq {
    virtual ~CBusReq() = default;

    virtual auto valid() const -> bool = 0;
    virtual auto is_write() const -> bool = 0;
    virtual auto size() const -> AXISize = 0;
    virtual auto addr() const -> word_t = 0;
    virtual auto strobe() const -> word_t = 0;
    virtual auto data() const -> word_t = 0;
    virtual auto len() const -> AXILength = 0;
};

struct CBusResp {
    static constexpr auto make_response(
        bool ready, bool last, word_t data
    ) -> CBusRespVType {
        return (uint64_t(ready) << 33) | (uint64_t(last) << 32) | data;
    }

    CBusResp() : ready(false), last(false), data(0) {}
    CBusResp(bool _ready, bool _last, word_t _data)
        : ready(_ready), last(_last), data(_data) {}
    CBusResp(const CBusResp &) = default;
    CBusResp(const CBusRespVType &resp)
        : ready((resp >> 33) & 1), last((resp >> 32) & 1), data(resp & 0xffffffff) {}

    auto operator=(const CBusResp &) -> CBusResp & = default;
    explicit operator CBusRespVType() {
        return make_response(ready, last, data);
    }

    bool ready;
    bool last;
    word_t data;
};

// a helper class/generator for CBusWrapper
template <typename VTopType>
class CBusWrapperGen : public CBusReq {
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
