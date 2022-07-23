`include "access.svh"
`include "common.svh"
`include "cache_manage.sv"

module VTop (
    input logic clk, resetn,

    output cbus_req_t  oreq,
    input  cbus_resp_t oresp,

    input i6 ext_int
);
    `include "bus_decl"

    ibus_req_t  ireq;
    ibus_resp_t iresp;
    dbus_req_t  dreq[1:0];
    dbus_resp_t dresp[1:0];
    cbus_req_t  icreq[1:0],  dcreq[1:0];
    cbus_resp_t icresp[1:0], dcresp[1:0];

    MyCore core(.*);
    cache_manage cache_manage(
        .dreq_1(dreq[1]),
        .dresp_1(dresp[1]),

        .dreq_2(dreq[0]),
        .dresp_2(dresp[0]),

        .creq(oreq),
        .cresp(oresp),
        .*
    );
    

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
