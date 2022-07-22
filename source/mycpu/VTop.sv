`include "access.svh"
`include "common.svh"

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
    cbus_req_t  icreq,  dcreq;
    cbus_resp_t icresp, dcresp;

    MyCore core(.*);
    /* IBusToCBus */ ICache icvt(.*);
    /* DBusToCBus */ DCache dcvt(.*, .dreq_1(dreq[1]), .dreq_2(dreq[0]),
    .dresp_1(dresp[1]), .dresp_2(dresp[0]));

    /**
     * TODO (Lab2) replace mux with your own arbiter :)
     */
    CBusArbiter mux(
        .ireqs({icreq, dcreq}),
        .iresps({icresp, dcresp}),
        .*
    );

    /**
     * TODO (optional) add address translation for oreq.addr :)
     */

    `UNUSED_OK({ext_int});
endmodule
