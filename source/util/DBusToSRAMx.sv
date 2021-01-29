`include "common.svh"
`include "sramx.svh"

/**
 * NOTE: SRAMx does not support byte write enables (strobe),
 *       nor unaligned accesses.
 */

module DBusToSRAMx (
    input  dbus_req_t   dreq,
    output dbus_resp_t  dresp,
    output sramx_req_t  dsreq,
    input  sramx_resp_t dsresp
);
    assign dsreq.req   =  dreq.valid;
    assign dsreq.wr    = |dreq.strobe;
    assign dsreq.size  =  dreq.size[1:0];
    assign dsreq.addr  =  dreq.addr;
    assign dsreq.wdata =  dreq.data;

    assign dresp.addr_ok = dsresp.addr_ok;
    assign dresp.data_ok = dsresp.data_ok;
    assign dresp.data    = dsresp.rdata;
endmodule
