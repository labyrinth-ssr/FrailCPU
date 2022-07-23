`ifndef __DBUSTOCBUS_SV
`define __DBUSTOCBUS_SV

`include "common.svh"

/**
 * NOTE: CBus does not support byte write enable mask (write_en).
 */

module DBusToCBus (
    input logic clk, resetn,
    input  dbus_req_t  dreq,
    output dbus_resp_t dresp,
    output cbus_req_t  dcreq,
    input  cbus_resp_t dcresp
);
    logic data_ok_reg;
    word_t data_reg;
    assign dcreq.valid    =  dreq.valid;
    assign dcreq.is_write = |dreq.strobe;
    assign dcreq.size     =  dreq.size;
    assign dcreq.addr     =  dreq.addr;
    assign dcreq.strobe   =  dreq.strobe;
    assign dcreq.data     =  dreq.data;
    assign dcreq.len      =  MLEN1;

    logic okay;
    assign okay = dcresp.ready && dcresp.last;

    always_ff @(posedge clk) begin
        if (resetn) begin
            data_ok_reg <= okay;
            data_reg <= dcresp.data;
        end
        else begin
            {data_ok_reg, data_reg} <= '0;
        end
        
    end

    assign dresp.addr_ok = okay;
    assign dresp.data_ok = data_ok_reg;
    assign dresp.data    = data_reg;
endmodule

`endif 
