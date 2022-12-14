`ifndef __HILO_SV
`define __HILO_SV

`ifdef VERILATOR
`include "common.svh"
`include "pipes.svh"
`else

`endif

module hilo 
    (
    input u1 clk,reset,
    output i32 hi, lo,
    input i1 hi_write, lo_write,
    input i32 hi_data, lo_data
);
    i32 hi_new, lo_new;
    always_comb begin
        {hi_new, lo_new} = {hi, lo};
        if (hi_write) begin
            hi_new = hi_data;
        end
        if (lo_write) begin
            lo_new = lo_data;
        end
    end
    always_ff @(posedge clk) begin
        if (reset) begin
            {hi,lo}<='0;
        end else begin
            
        {hi, lo} <= {hi_new, lo_new};
        end
    end
endmodule

`endif
