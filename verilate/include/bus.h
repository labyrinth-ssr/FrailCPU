#pragma once

#include "common.h"

/**
 * cache bus (CBus)
 */

using CBusReqVType = uint32_t[3];  // 77 bits
using CBusRespVType = uint64_t;  // 34 bits

// CBusReq is used by CBusDevice, and therefore it must be portable.
// Therefore, we declare CBusReq as a pure virtual class, effectively
// an interface.
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
template <typename VModelScope>
class CBusWrapperGen : public CBusReq {
public:
    CBusWrapperGen(VModelScope *_top, const CBusReqVType &_req)
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
    VModelScope *top;
    const CBusReqVType &req;
};

/**
 * data bus (DBus)
 */

using DBusReqVType = uint32_t[3];  // 72 bits
using DBusRespVType = uint64_t;  // 33 bits

struct DBusPorts {
    DBusPorts(DBusReqVType &_req, DBusRespVType &_resp)
        : req(_req), resp(_resp) {}

    DBusReqVType &req;
    DBusRespVType &resp;
};

template <typename VModel, typename VModelScope>
class DBusGen {
public:
    DBusGen(VModel *_top, VModelScope *_scope, const DBusPorts &_ports)
        : top(_top), scope(_scope), ports(_ports) {}

    /**
     * DBus request interface
     */

    auto valid() const -> bool {
        return scope->dbus_req_t_valid(ports.req);
    }
    auto size() const -> AXISize {
        return static_cast<AXISize>(scope->dbus_req_t_size(ports.req));
    }
    auto addr() const -> addr_t {
        return scope->dbus_req_t_addr(ports.req);
    }
    auto strobe() const -> word_t {
        return scope->dbus_req_t_strobe(ports.req);
    }
    auto wdata() const -> word_t {  // req.data
        return scope->dbus_req_t_data(ports.req);
    }

    /**
     * DBus response interface
     */

    auto addr_ok() const -> bool {
        return scope->dbus_resp_t_addr_ok(ports.resp);
    }
    auto data_ok() const -> bool {
        return scope->dbus_resp_t_data_ok(ports.resp);
    }
    auto rdata() const -> word_t {  // resp.data
        return scope->dbus_resp_t_data(ports.resp);
    }

    /**
     * some helper functions
     */

    // NOTE: it is asynchronous
    void issue(bool valid, addr_t addr, AXISize size, word_t strobe, word_t data) {
        scope->dbus_update(valid, addr, size, strobe, data, ports.req);
        top->eval();
    }
    void clear() {
        scope->dbus_reset_valid(ports.req);
        top->eval();
    }

    void async_load(addr_t addr, AXISize size) {
        scope->dbus_issue_load(addr, size, ports.req);
        top->eval();
    }
    auto load(addr_t addr, AXISize size) -> word_t {
        async_load(addr, size);
        return await<true, true, false>();
    }
    void async_store(addr_t addr, AXISize size, word_t strobe, word_t data) {
        scope->dbus_issue_store(addr, size, strobe, data, ports.req);
        top->eval();
    }
    void store(addr_t addr, AXISize size, word_t strobe, word_t data) {
        async_store(addr, size, strobe, data);
        await<true, true, false>();
    }

    // return the data at the last handshake
    // max_count is the maximum number of ticks
    template <bool WaitDataOk = true, bool WaitAddrOk = true, bool EvalFirst = true>
    auto await(uint64_t max_count = UINT64_MAX) -> word_t {
        uint32_t remain = 0;
        if (WaitDataOk)
            remain |= 1 << 1;
        if (WaitAddrOk)
            remain |= 1 << 0;

        if (EvalFirst)
            top->eval();

        uint64_t count = 0;
        while (true) {
            word_t data = rdata();
            remain ^= scope->dbus_handshake(ports.resp, remain);
            if (remain == 0)
                return data;

            count++;
            if (count <= max_count)
                top->tick();
            else
                break;
        }

        assert(false);
    }

private:
    VModel *top;
    VModelScope *scope;
    DBusPorts ports;
};
