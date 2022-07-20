`include "pipes.svh"

module pipereg
 #(
    parameter type T=fetch_data_t
) (
    input clk,
    input reset,
    input T in,
    output T out,
    input en,flush
);
always_ff @( posedge clk ) begin
        if (reset||flush) begin 
            out <= '0;
        end else if (en) begin
            out <= in;
        end
    end

endmodule
