`ifndef __CACHE_MANAGE_SV
`define __CACHE_MANAGE_SV

`include "common.svh"
`ifdef VERILATOR
`include "ICache.sv"
`include "DCache.sv"
`include "../../util/CBusArbiter.sv"
`endif 
module cache_manage (
    input logic clk, resetn,

    input ibus_req_t ireq,
    output ibus_resp_t iresp,

    input dbus_req_t dreq_1,
    input dbus_req_t dreq_2,
    output dbus_resp_t dresp,

    output cbus_req_t  creq,
    input cbus_resp_t cresp,
    input icache_inst_t icache_inst,
    input dcache_inst_t dcache_inst,
    input word_t tag_lo
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

    //地址转换
    ibus_req_t mmu_ireq_1,mmu_ireq_2;
    ibus_resp_t mmu_iresp;

    dbus_req_t mmu_dreq_1;
    dbus_req_t mmu_dreq_2;
    dbus_resp_t mmu_dresp;

    always_comb begin
        mmu_ireq_1 = ireq;
        mmu_ireq_1.addr = mmu_ireq_addr; //V->P
    end

    always_comb begin
        mmu_ireq_2= ireq;
        mmu_ireq_2.addr = mmu_ireq_addr+4; //V->P
    end
    assign iresp = mmu_iresp;

    always_comb begin
        mmu_dreq_1 = dreq_1;
        mmu_dreq_1.addr = mmu_dreq_1_addr;
    end
    assign dreq_1_uncache = dreq_1.addr[31:29]==3'b101;
    always_comb begin
        mmu_dreq_2 = dreq_2;
        mmu_dreq_2.addr = mmu_dreq_2_addr;
    end
    assign dreq_2_uncache = dreq_2.addr[31:29]==3'b101;
    assign dresp = mmu_dresp;


    //cbus
    cbus_req_t i_cbus_req;
    cbus_resp_t i_cbus_resp;

    cbus_req_t d_cbus_req;
    cbus_resp_t d_cbus_resp;

    cbus_req_t oreq;
    cbus_resp_t oresp;


    ICache icache (
        .clk, 
        .resetn,
        .ireq_1(mmu_ireq_1),
        .ireq_2(mmu_ireq_2),
        .iresp(mmu_iresp),
        .icreq(i_cbus_req),
        .icresp(i_cbus_resp),

        .cache_inst(icache_inst),
        .tag_lo
    );

    DCache dcache (
        .clk, 
        .resetn,
        .dreq_1(mmu_dreq_1),
        .dreq_1_is_uncached(dreq_1_uncache),
        .dreq_2(mmu_dreq_2),
        .dreq_2_is_uncached(dreq_2_uncache),
        .dresp(mmu_dresp),
        .dcreq(d_cbus_req),
        .dcresp(d_cbus_resp),

        .cache_inst(dcache_inst),
        .tag_lo
    );

   

    MyArbiter #(
        .NUM_INPUTS(2)
    ) cbus_arbiter (
        .clk, 
        .resetn,
        .ireqs({i_cbus_req, d_cbus_req}),
        .iresps({i_cbus_resp, d_cbus_resp}),
        .oreq(creq),
        .oresp(cresp)
    );




endmodule

`endif