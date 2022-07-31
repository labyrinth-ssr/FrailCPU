`ifndef __RPCT_SV
`define __RPCT_SV

`include "common.svh"
`include "plru.sv"

module RPCT #(
    parameter int ASSOCIATIVITY = 8,
    parameter int SET_NUM = 2,
    
    localparam INDEX_BITS = $clog2(SET_NUM),
    localparam ASSOCIATIVITY_BITS = $clog2(ASSOCIATIVITY),
    localparam TAG_BITS = 30 - INDEX_BITS,
    localparam type tag_t = logic [TAG_BITS-1:0],
    localparam type index_t = logic [INDEX_BITS-1:0],
    localparam type associativity_t = logic [ASSOCIATIVITY_BITS-1:0],
    localparam type plru_t = logic [ASSOCIATIVITY-2:0],
    localparam type meta_t = struct packed {
        logic valid;
        tag_t tag;
    },
    localparam type ram_addr_t = struct packed {
        index_t index;
        associativity_t line;
    }
) (
    input logic clk, resetn,
    input logic is_write, // if this instr write in to rpct (jr (ra))
    input addr_t pc_check, jrra_pc,
    /*
    * pc_check is the pc to be predicted(from f1)
    * jrra_pc is the pc of the jr (ra) or jalr (from exe)
    */
    output logic hit
);

    function tag_t get_tag(addr_t addr);
        return addr[32:2+INDEX_BITS];
    endfunction

    function index_t get_index(addr_t addr);
        return addr[2+INDEX_BITS-1:2];
    endfunction

    meta_t [ASSOCIATIVITY-1:0] r_meta_hit;
    meta_t [ASSOCIATIVITY-1:0] r_meta_in_rpct;
    meta_t [ASSOCIATIVITY-1:0] w_meta;
    associativity_t replace_line;
    ram_addr_t replace_addr;
    // logic in_bht;

    // for predict

    always_comb begin
        hit = 1'b0;
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            if (r_meta_hit[i].valid && r_meta_hit[i].tag == get_tag(pc_check)) begin
                hit = 1'b1;
            end
        end 
    end


    // for repalce

    // always_comb begin
    //     in_bht = 1'b0;
    //     for (int i = 0; i < ASSOCIATIVITY; i++) begin
    //         if (r_meta_in_bht[i].valid && r_meta_in_bht[i].tag == get_tag(executed_branch_pc)) begin
    //             in_bht = 1'b1;
    //         end
    //     end 
    // end

    plru_t plru_ram [SET_NUM-1 : 0];
    plru_t plru_r, plru_new;

    assign plru_r = plru_ram[get_index(pc_check)];

    plru port_1_plru(
        .plru_old(plru_r),
        .hit_line(hit_line),
        .plru_new(plru_new),
        .replace_line(replace_line)
    );

    always_ff @(posedge clk) begin
        if (hit) begin
            plru_ram[predict_addr.index] <= plru_new;
        end
    end

    assign replace_addr.line = replace_line;
    assign replace_addr.index = get_index(jrra_pc);


    always_comb begin
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            if (/*~in_bht &&*/ is_write && i == replace_line) begin
                w_meta[i].valid = 1'b1;
                w_meta[i].tag = get_tag(jrra_pc);
            end else begin
                w_meta[i] = r_meta_in_rpct[i];
            end
        end 
    end



    LUTRAM_DualPort #(
        .ADDR_WIDTH(INDEX_BITS),
        .DATA_WIDTH($bits(meta_t) * ASSOCIATIVITY),
        .BYTE_WIDTH($bits(meta_t) * ASSOCIATIVITY),
        .READ_LATENCY(0)
    ) meta_ram(
        .clk(clk),
        .resetn,

        .en_1(1'b1), //port1 for replace
        .addr_1(replace_addr.index),
        .rdata_1(r_meta_in_rpct),
        .strobe(1'b1),  
        .wdata(w_meta),

        .en_2(1'b0), //port2 for predict
        .addr_2(predict_addr.index),
        .rdata_2(r_meta_hit)
    );

endmodule


`endif 
