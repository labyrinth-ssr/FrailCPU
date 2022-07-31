`ifndef __CACHE_MANAGE_SV
`define __CACHE_MANAGE_SV

`include "common.svh"
`ifdef VERILATOR
`include "ICache.sv"
`include "DCache.sv"
`include "../../util/CBusArbiter.sv"
`include "../../util/DBusToCBus.sv"
`endif 
module cache_manage (
    input logic clk, resetn,

    input ibus_req_t ireq,
    output ibus_resp_t iresp,

    input dbus_req_t dreq_1,
    output dbus_resp_t dresp_1,

    input dbus_req_t dreq_2,
    output dbus_resp_t dresp_2,

    output cbus_req_t  creq,
    input cbus_resp_t cresp
);

    logic dreq_1_uncache;
    logic dreq_2_uncache;

    addr_t mmu_ireq_addr;
    addr_t mmu_dreq_1_addr;
    addr_t mmu_dreq_2_addr;

    pvtrans i_pvtrans(
        .vaddr(ireq.addr),
        .paddr(mmu_ireq_addr)
    );
    pvtrans d_1_pvtrans(
        .vaddr(dreq_1.addr),
        .paddr(mmu_dreq_1_addr)
    );
    pvtrans d_2_pvtrans(
        .vaddr(dreq_2.addr),
        .paddr(mmu_dreq_2_addr)
    );

    //TU
    ibus_req_t mmu_ireq;
    ibus_resp_t mmu_iresp;

    always_comb begin
        mmu_ireq = ireq;
        mmu_ireq.addr = mmu_ireq_addr; //V->P

        iresp = mmu_iresp;
    end

    dbus_req_t mmu_dreq_1;
    dbus_resp_t mmu_dresp_1;

    always_comb begin
        mmu_dreq_1 = dreq_1;
        mmu_dreq_1.addr = mmu_dreq_1_addr;

        dresp_1 = mmu_dresp_1;

        dreq_1_uncache = dreq_1.addr[29];
    end

    dbus_req_t mmu_dreq_2;
    dbus_resp_t mmu_dresp_2;

    always_comb begin
        mmu_dreq_2 = dreq_2;
        mmu_dreq_2.addr = mmu_dreq_2_addr;

        dresp_2 = mmu_dresp_2;
        
        dreq_2_uncache = dreq_2.addr[29];
    end


    //ibus cache
    ibus_req_t ibus_cache_req;
    ibus_resp_t ibus_cache_resp;

    assign ibus_cache_req = mmu_ireq;
    assign mmu_iresp = ibus_cache_resp;

    //dbus cache
    dbus_req_t dbus_cache_req_1;
    dbus_resp_t dbus_cache_resp_1;

    //传送首个有效cache请求
    assign dbus_cache_req_1 = (~dreq_1_uncache & mmu_dreq_1.valid) ? mmu_dreq_1
                                                                   : (~dreq_2_uncache & mmu_dreq_2.valid) ? mmu_dreq_2
                                                                                                          : '0;

    dbus_req_t dbus_cache_req_2;
    dbus_resp_t dbus_cache_resp_2;

    //在第一个为cache请求下，传送第二个有效cache请求
    assign dbus_cache_req_2 = (~dreq_1_uncache & mmu_dreq_1.valid & ~dreq_2_uncache & mmu_dreq_2.valid) ? mmu_dreq_2 : '0;
    
    //dbus uncache
    dbus_req_t dbus_uncache_req_1;
    dbus_resp_t dbus_uncache_resp_1;

    assign dbus_uncache_req_1 = dreq_1_uncache ? mmu_dreq_1 : '0;

    dbus_req_t dbus_uncache_req_2;
    dbus_resp_t dbus_uncache_resp_2;

    assign dbus_uncache_req_2 = dreq_2_uncache ? mmu_dreq_2 : '0;

    logic uncache_1_valid_reg;
    logic uncache_2_valid_reg;
    logic cache_1_valid_reg;
    logic cache_2_valid_reg;

    //resp用处不大
    assign mmu_dresp_1.addr_ok = dbus_uncache_req_1.valid ? dbus_uncache_resp_1.addr_ok
                                                  : dbus_cache_req_1.valid ? dbus_cache_resp_1.addr_ok
                                                                           : '0;
    assign mmu_dresp_2.addr_ok = dbus_uncache_req_2.valid ? dbus_uncache_resp_2.addr_ok
                                                  : dbus_cache_req_2.valid ? dbus_cache_resp_2.addr_ok
                                                                           : dbus_cache_req_1.valid ? dbus_cache_resp_1.addr_ok
                                                                                                    : '0;
    
    always_ff @(posedge clk) begin
        if (resetn) begin
            uncache_1_valid_reg <= dbus_uncache_req_1.valid;
            uncache_2_valid_reg <= dbus_uncache_req_2.valid;
            cache_1_valid_reg <= dbus_cache_req_1.valid;
            cache_2_valid_reg <= dbus_cache_req_2.valid;    
        end
        else begin
            uncache_1_valid_reg <= '0;
            uncache_2_valid_reg <= '0;
            cache_1_valid_reg <= '0;
            cache_2_valid_reg <= '0;
        end
    end

    assign {mmu_dresp_1.data_ok, mmu_dresp_1.data} = uncache_1_valid_reg ? {dbus_uncache_resp_1.data_ok, dbus_uncache_resp_1.data}
                                                  : cache_1_valid_reg ? {dbus_cache_resp_1.data_ok, dbus_cache_resp_1.data}
                                                                           : '0;
    assign {mmu_dresp_2.data_ok, mmu_dresp_2.data} = uncache_2_valid_reg ? {dbus_uncache_resp_2.data_ok, dbus_uncache_resp_2.data}
                                                  : cache_2_valid_reg ? {dbus_cache_resp_2.data_ok, dbus_cache_resp_2.data}
                                                                     : cache_1_valid_reg ? {dbus_cache_resp_1.data_ok, dbus_cache_resp_1.data}
                                                                                                    : '0;


    //cbus
    cbus_req_t i_cbus_req;
    cbus_resp_t i_cbus_resp;

    cbus_req_t d_cache_cbus_req;
    cbus_resp_t d_cache_cbus_resp;

    cbus_req_t d_uncache1_cbus_req;
    cbus_resp_t d_uncache1_cbus_resp;

    cbus_req_t d_uncache2_cbus_req;
    cbus_resp_t d_uncache2_cbus_resp;

    cbus_req_t oreq;
    cbus_resp_t oresp;


    ICache icache (
        .clk, 
        .resetn,
        .ireq(ibus_cache_req),
        .iresp(ibus_cache_resp),
        .icreq(i_cbus_req),
        .icresp(i_cbus_resp)
    );

    DCache dcache (
        .clk, 
        .resetn,
        .dreq_1(dbus_cache_req_1),
        .dresp_1(dbus_cache_resp_1),
        .dreq_2(dbus_cache_req_2),
        .dresp_2(dbus_cache_resp_2),
        .dcreq(d_cache_cbus_req),
        .dcresp(d_cache_cbus_resp)
    );

    DBusToCBus uncache_1 (
        .dreq(dbus_uncache_req_1),
        .dresp(dbus_uncache_resp_1),
        .dcreq(d_uncache1_cbus_req),
        .dcresp(d_uncache1_cbus_resp),
        .*
    );

    DBusToCBus uncache_2 (
        .dreq(dbus_uncache_req_2),
        .dresp(dbus_uncache_resp_2),
        .dcreq(d_uncache2_cbus_req),
        .dcresp(d_uncache2_cbus_resp),
        .*
    );

    MyArbiter #(
        .NUM_INPUTS(4)
    ) cbus_arbiter (
        .clk, 
        .resetn,
        .ireqs({i_cbus_req, d_uncache2_cbus_req, d_cache_cbus_req, d_uncache1_cbus_req}),
        .iresps({i_cbus_resp, d_uncache2_cbus_resp, d_cache_cbus_resp, d_uncache1_cbus_resp}),
        .oreq(creq),
        .oresp(cresp)
    );




endmodule

`endif