// aliasing file for reference CPU

`include "Common.svh"

module MyCPU (
    input logic clk, resetn,

    output ibus_req_t  ireq,
    input  ibus_resp_t iresp,
    output dbus_req_t  dreq,
    input  dbus_resp_t dresp
);
    RefCPU cpu_inst(.*);
endmodule