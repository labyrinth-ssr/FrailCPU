`include "access.svh"
`include "refcpu/defs.svh"

module VTop (
    input logic clk, resetn,

    output cbus_req_t  oreq,
    input  cbus_resp_t oresp
);
    `include "cbus_decl"

    `STRUCT_ACCESSOR(context_t, state, cpu_state_t);
    `STRUCT_ACCESSOR(context_t, pc, addr_t);
    `STRUCT_ACCESSOR(context_t, next_pc, addr_t);

    ibus_req_t  ireq;
    ibus_resp_t iresp;
    dbus_req_t  dreq;
    dbus_resp_t dresp;
    cbus_req_t  icreq,  dcreq;
    cbus_resp_t icresp, dcresp;

    Core core(.*);
    IBusToCBus icvt(.*);
    DBusToCBus dcvt(.*);
    CBusArbiter arbiter(
        .ireqs({icreq, dcreq}),
        .iresps({icresp, dcresp}),
        .*
    );
endmodule
