`include "access.svh"
`include "common.svh"
`include "cache_pkg.svh"
`ifdef VERILATOR
`include "cache/cache_manage.sv"
`endif 


module VTop (
    input logic clk, resetn,

    output cbus_req_t  oreq,
    input  cbus_resp_t oresp,

    input i6 ext_int
);
    `include "bus_decl"

    ibus_req_t  ireq;
    ibus_resp_t iresp;
    dbus_req_t  [1:0] dreq;
    dbus_resp_t dresp;
    icache_inst_t icache_inst;
    dcache_inst_t dcache_inst;
    word_t tag_lo;


    MyCore core(.*);
    cache_manage cache_manage(
        .dreq_1(dreq[1]),
        .dreq_2(dreq[0]),
        .dresp(dresp),
        .creq(oreq),
        .cresp(oresp),
        .*
    );

    // ireq_interface a (._ireq(ireq),.ireq_1(icreq[1]),.ireq_2(icreq[0]),.iresp_1(icresp[1]),.iresp_2(icresp[0]),._iresp(iresp),.*);

    // // /* IBusToCBus */ ICache icvt(.*);
    // // /* DBusToCBus */ DCache dcvt(.*, .dreq_1(dreq[1]), .dreq_2(dreq[0]),
    // // .dresp_1(dresp[1]), .dresp_2(dresp[0]));
    // u1 req1_finish,req2_finish;
    //     always_ff @(posedge clk) begin
    //     if (dcreq[1].valid&&dcresp[1].last) begin
    //         req1_finish<='1;
    //     end else if (req1_finish&&dcreq[0].valid) begin
    //         req1_finish<='1;
    //     end else begin
    //         req1_finish<='0;
    //     end
    // end

    // always_ff @(posedge clk) begin
    //     if (dcreq[0].valid&&dcresp[0].last) begin
    //         req2_finish<='1;
    //     end else begin
    //         req2_finish<='0;
    //     end
    // end

    // assign dresp[1].data=dcresp[1].data;
    // assign dresp[1].data_ok=dcresp[1].last;
    // assign dresp[1].addr_ok=dcresp[1].last;

    // assign dresp[0].data=dcresp[0].data;
    // assign dresp[0].data_ok=dcresp[0].last;
    // assign dresp[0].addr_ok=dcresp[0].last;

    // assign dcreq[1].valid = req1_finish? '0:dreq[1].valid;
    // assign dcreq[1].is_write = |dreq[1].strobe;
    // assign dcreq[1].size = dreq[1].size;
    // assign dcreq[1].addr = dreq[1].addr;
    // assign dcreq[1].strobe = dreq[1].strobe;
    // assign dcreq[1].data = dreq[1].data;
    // assign dcreq[1].len = MLEN1;

    // assign dcreq[0].valid = req2_finish? '0: dreq[0].valid;
    // assign dcreq[0].is_write = |dreq[0].strobe;
    // assign dcreq[0].size = dreq[0].size;
    // assign dcreq[0].addr = dreq[0].addr;
    // assign dcreq[0].strobe = dreq[0].strobe;
    // assign dcreq[0].data = dreq[0].data;
    // assign dcreq[0].len = MLEN1;
    /**
     * TODO (Lab2) replace mux with your own arbiter :)
     */
     /*
    CBusArbiter mux(
        .ireqs({icreq[1],icreq[0] ,dcreq[1],dcreq[0]}),
        .iresps({icresp[1],icresp[0] ,dcresp[1],dcresp[0]}),
        .*
    );
    */

    /**
     * TODO (optional) add address translation for oreq.addr :)
     */

    `UNUSED_OK({ext_int});
endmodule
