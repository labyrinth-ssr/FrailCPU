`include "Common.svh"

/**
 * NOTE: CBus does not support byte write enable mask (write_en).
 */

module DBusToCBus (
    input  dbus_req_t  dreq,
    output dbus_resp_t dresp,
    output cbus_req_t  creq,
    input  cbus_resp_t cresp
);
    assign creq.valid    = dreq.valid;
    assign creq.is_write = |dreq.write_en;
    assign creq.order    = '0;
    assign creq.addr     = dreq.addr;
    assign creq.data     = dreq.data;

    logic okay;
    assign okay = cresp.ready && cresp.last;

    assign dresp.addr_ok = okay;
    assign dresp.data_ok = okay;
    assign dresp.data = cresp.data;
endmodule
