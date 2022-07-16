`include "common.svh"

//七位PLRU值
module PLRU #(
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
    assign replace_line[1] = plru_old[plru_old[0] + 1];
    assign replace_line[0] = plru_old[plru_old[0] << 1 + 3 + plru_old[plru_old[0] + 1]];

    always_comb begin
        plru_new = plru_old;

        plru_new[0] = ~hit_line[2];
        plru_new[hit_line[2] + 1] = ~hit_line[1];
        plru_new[hit_line[2] << 1 + 3 + hit_line[1]] = ~hit_line[0];
    end
   

endmodule
