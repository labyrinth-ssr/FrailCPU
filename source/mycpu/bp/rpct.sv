`ifndef __RPCT_SV
`define __RPCT_SV

`include "common.svh"


module rpct #(
    parameter int ASSOCIATIVITY = 2,
    parameter int SET_NUM = 4,
    
    localparam INDEX_BITS = $clog2(SET_NUM),
    localparam ASSOCIATIVITY_BITS = $clog2(ASSOCIATIVITY),
    localparam TAG_BITS = 18,
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
    output logic hit, hit_pc, hit_pcp4
);

    function tag_t get_tag(addr_t addr);
        return addr[2+TAG_BITS-1:2];
    endfunction

    function index_t get_index(addr_t addr);
        return addr[2+INDEX_BITS-1+2:2+2];
    endfunction

    meta_t [ASSOCIATIVITY-1:0] r_meta_hit;
    meta_t [ASSOCIATIVITY-1:0] r_meta_in_rpct;
    meta_t [ASSOCIATIVITY-1:0] w_meta;
    associativity_t replace_line, hit_line, pc_hit_line, pcp4_hit_line;
    ram_addr_t replace_addr;
    logic pc_hit, pcp4_hit, in_rpct;

    // for predict

    always_comb begin
        pc_hit = 1'b0;
        pc_hit_line = '0;
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            if (r_meta_hit[i].valid && (r_meta_hit[i].tag == get_tag(pc_check))) begin
                pc_hit  = 1'b1;
                pc_hit_line = associativity_t'(i);
            end
        end 
    end

    always_comb begin
        pcp4_hit = 1'b0;
        pcp4_hit_line = '0;
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            if (r_meta_hit[i].valid && (r_meta_hit[i].tag == get_tag(pc_check+4))) begin
                pcp4_hit = 1'b1;
                pcp4_hit_line = associativity_t'(i);
            end
        end 
    end

    assign hit_pc = pc_hit;
    assign hit_pcp4 = pcp4_hit;
    assign hit = pcp4_hit | pc_hit;
    always_comb begin : hit_line_b
        hit_line = '0;
        if(pc_hit) hit_line = pc_hit_line;
        else if(pcp4_hit) hit_line = pcp4_hit_line;
    end


    // for repalce

    always_comb begin
        in_rpct = 1'b0;
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            if (r_meta_in_rpct[i].valid && r_meta_in_rpct[i].tag == get_tag(jrra_pc)) begin
                in_rpct = 1'b1;
            end
        end 
    end

    plru_t plru_ram [SET_NUM-1 : 0];
    plru_t plru_r, plru_new;

    assign plru_r = plru_ram[get_index(pc_check)];

    assign replace_line[0] = plru_r[0];
    assign plru_new[0] = ~hit_line[0];

    always_ff @(posedge clk) begin
        if (hit) begin
            plru_ram[get_index(pc_check)] <= plru_new;
        end
    end

    assign replace_addr.line = replace_line;
    assign replace_addr.index = get_index(jrra_pc);


    always_comb begin : w_meta_block
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            if (~in_rpct && is_write && associativity_t'(i) == replace_line) begin
                w_meta[i].valid = 1'b1;
                w_meta[i].tag = get_tag(jrra_pc);
            end else begin
                w_meta[i] = r_meta_in_rpct[i];
            end
        end 
    end

    index_t reset_addr;

    always_ff @( posedge clk ) begin : reset
            reset_addr <= reset_addr+1;
    end


    LUTRAM_DualPort #(
        .ADDR_WIDTH(INDEX_BITS),
        .DATA_WIDTH($bits(meta_t) * ASSOCIATIVITY),
        .BYTE_WIDTH($bits(meta_t) * ASSOCIATIVITY),
        .READ_LATENCY(0)
    ) meta_ram(
        .clk(clk),

        .en_1(is_write | ~resetn), //port1 for replace
        .addr_1(resetn ? replace_addr.index : reset_addr),
        .rdata_1(r_meta_in_rpct),
        .strobe(is_write | ~resetn),  
        .wdata(resetn ? w_meta : '0),

        .en_2(1'b1), //port2 for predict
        .addr_2(get_index(pc_check)),
        .rdata_2(r_meta_hit)
    );

endmodule


`endif 