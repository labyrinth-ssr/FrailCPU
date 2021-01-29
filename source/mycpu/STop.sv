`include "common.svh"
`include "sramx.svh"

/**
 * this top module is used for Lab1 only.
 * "S" stands for the SRAMx bus.
 */

module STop (
    input logic clk, resetn,

    output sramx_req_t  isreq,  dsreq,
    input  sramx_resp_t isresp, dsresp
);
    ibus_req_t  ireq;
    ibus_resp_t iresp;
    dbus_req_t  dreq;
    dbus_resp_t dresp;

    MyCore core(.*);
    IBusToSRAMx icvt(.*);
    DBusToSRAMx dcvt(.*);
endmodule
