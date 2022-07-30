`ifndef __PLRU_SV
`define __PLRU_SV

`include "common.svh"

//七位PLRU值
module plru #(
    parameter int ASSOCIATIVITY = 8,

    localparam ASSOCIATIVITY_BITS = $clog2(ASSOCIATIVITY),
    localparam type plru_t = logic [ASSOCIATIVITY-2:0],
    localparam type associativity_t = logic [ASSOCIATIVITY_BITS-1:0]
) (
    input plru_t plru_old,
    input associativity_t hit_line,
    output plru_t plru_new,
    output associativity_t replace_line
);

    assign replace_line[2] = plru_old[0];
    assign replace_line[1] = plru_old[0] ? plru_old[2] : plru_old[1];
    assign replace_line[0] = plru_old[ {30'b0, plru_old[0], 1'b0} + 3 + ( plru_old[0] ? int'(plru_old[2]) : int'(plru_old[1]) ) ];

    always_comb begin
        plru_new = plru_old;

        plru_new[0] = ~hit_line[2];

        if (hit_line[2]) begin
            plru_new[2] = ~hit_line[1];
        end 
        else begin
            plru_new[1] = ~hit_line[1];
        end

        for (int i = 0; i < $bits(plru_t); i++) begin
            if (i == {30'b0, hit_line[2], 1'b0} + 3 + int'(hit_line[1])) begin
                plru_new[i] = ~hit_line[0];
            end
            else begin
            end
        end

    end
   

endmodule


`endif 
