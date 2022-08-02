`ifndef __ICACHE_SV
`define __ICACHE_SV

`include "common.svh"
`ifdef VERILATOR

`include "../plru.sv"
`endif 
module ICache (
    input logic clk, resetn,

    input  ibus_req_t  ireq,
    output ibus_resp_t iresp,
    output cbus_req_t  icreq,
    input  cbus_resp_t icresp
);

    //16KB 2路组相联 1行8个data
    //1 + 7 + 3 + 3
    localparam DATA_PER_LINE = 8;
    localparam ASSOCIATIVITY = 2;
    localparam SET_NUM = 128;

    localparam BYTE_WIDTH = 8;
    localparam BYTE_PER_DATA = 8;
    localparam DATA_WIDTH = BYTE_WIDTH * BYTE_PER_DATA;

    localparam BYTE_PER_WORD = 4;
    localparam WORD_WIDTH = BYTE_WIDTH * BYTE_PER_WORD;
    localparam WORD_PER_DATA = DATA_WIDTH / WORD_WIDTH;
    localparam WORD_PER_LINE = WORD_PER_DATA * DATA_PER_LINE;

    localparam DATA_BITS = $clog2(BYTE_PER_DATA);
    localparam OFFSET_BITS = $clog2(DATA_PER_LINE);
    localparam ASSOCIATIVITY_BITS = $clog2(ASSOCIATIVITY);
    localparam INDEX_BITS = $clog2(SET_NUM);
    localparam WORD_PER_LINE_BITS = $clog2(WORD_PER_LINE);
    localparam TAG_BITS = 32 - INDEX_BITS - OFFSET_BITS - DATA_BITS; 

    localparam DATA_ADDR_BITS = ASSOCIATIVITY_BITS + INDEX_BITS + OFFSET_BITS;

    localparam type data_t = logic [DATA_WIDTH-1:0];
    localparam type align_t = logic [DATA_BITS-1:0];
    localparam type offset_t = logic [OFFSET_BITS-1:0];
    localparam type associativity_t = logic [ASSOCIATIVITY_BITS-1:0];
    localparam type index_t = logic [INDEX_BITS-1:0];
    localparam type tag_t = logic [TAG_BITS-1:0];
    localparam type data_addr_t = struct packed {
        associativity_t line;
        index_t index;
        offset_t offset;
    };
    localparam type addr_t = struct packed {
        tag_t tag;
        index_t index;
        offset_t offset;
        align_t align;
    };

    localparam type record_t = logic [WORD_PER_LINE-1:0];
    localparam type cbus_num_t = logic [WORD_PER_LINE_BITS-1:0];

    localparam type plru_t = logic [ASSOCIATIVITY-2:0];

    localparam type cbus_state_t = enum logic {
        IDLE, FETCH
    };

    addr_t ireq_addr;
    assign ireq_addr = ireq.addr;

    index_t reset_counter;
    always_ff @(posedge clk) begin
        reset_counter <= reset_counter + 1;
    end

    //meta_ram
    typedef struct packed {
        logic valid;
        tag_t tag;
    } info_t;

    localparam type meta_t = info_t [ASSOCIATIVITY-1:0];

    index_t meta_addr;
    meta_t meta_r, meta_w;
    assign meta_addr = resetn ? ireq_addr.index : reset_counter[INDEX_BITS-1:0];

    RAM_SinglePort #(
        .ADDR_WIDTH(INDEX_BITS),
        .DATA_WIDTH($bits(meta_t)),
        .BYTE_WIDTH($bits(meta_t)),
        .MEM_TYPE(0),
        .READ_LATENCY(0)
    ) meta_ram(
        .clk(clk), 
        .en(1'b1),
        .addr(meta_addr),
        .strobe(1'b1),
        .wdata(meta_w),
        .rdata(meta_r)
    );

    //计算hit
    logic hit;
    logic [ASSOCIATIVITY-1:0] hit_bits;
    associativity_t hit_line;
    for (genvar i = 0; i < ASSOCIATIVITY; i++) begin
        assign hit_bits[i] = meta_r[i].valid && meta_r[i].tag == ireq_addr.tag;
    end
    assign hit = |hit_bits;
    always_comb begin
        hit_line = 0;
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            hit_line |= hit_bits[i] ? associativity_t'(i) : 0;
        end
    end

    //plru_ram
    // plru_t [SET_NUM-1 : 0] plru_ram;

    // //plru_r -> replace_line
    // //hit_line + plru_r -> plru_new
    // associativity_t replace_line;
    // plru_t plru_new;
    // /*
    // double miss -> stall forever
    // */
    // plru plru(
    //     .plru_old(plru_ram[ireq_addr.index]),
    //     .hit_line,
    //     .plru_new,
    //     .replace_line
    // );

    //plru
    plru_t [SET_NUM-1 : 0] plru, plru_new;
    associativity_t replace_line;

    assign replace_line = plru[ireq_addr.index];
    
    always_comb begin
        plru_new = plru;
        for (int i = 0; i < SET_NUM; i++) begin 
            if (ireq_hit) begin
                plru_new[i] = (ireq_addr.index == index_t'(i)) ? ~hit_line : plru[i];
            end    
        end
    end

    always_ff @(posedge clk) begin
        if (resetn) begin
            plru <= plru_new;
        end
        else begin
            plru <= '0;
        end
    end

    //Port 1 
    data_addr_t data_addr;
    data_t data_r;
    assign data_addr = {hit_line, ireq_addr.index, ireq_addr.offset};

    logic data_ok_reg;

    //Port 2
    logic port_2_en;
    double_strobe_t port_2_wen;
    data_addr_t port_2_addr;
    data_t port_2_data_w;

    data_addr_t miss_data_addr; //内存->Cache

    //fetch finish
    record_t fetch_finish;
    record_t part_fetch_finish;
    cbus_num_t fetch_count;

    //cbus_state
    cbus_state_t state;

    //cbus
    addr_t cbus_addr;   //内存->Cache
    
    assign port_2_en = 1'b1;
    assign port_2_wen = (state == FETCH && icresp.ready) ? (fetch_count[0] ? {{BYTE_PER_WORD{1'b1}}, {BYTE_PER_WORD{1'b0}}} : {{BYTE_PER_WORD{1'b0}}, {BYTE_PER_WORD{1'b1}}})
                                                                     : '0;
    assign port_2_addr = miss_data_addr;
    assign port_2_data_w = (state == FETCH & icresp.ready) ? (fetch_count[0] ? {icresp.data, {WORD_WIDTH{1'b0}}} : {{WORD_WIDTH{1'b0}}, icresp.data})
                                                            : '0;


    for (genvar i = 0; i < WORD_PER_LINE; i = i + 2) begin
        assign fetch_finish[i] = part_fetch_finish[i] & part_fetch_finish[i+1];
        assign fetch_finish[i+1] = part_fetch_finish[i+1];
    end

    //hit && miss
    logic hit_avail;
    logic ireq_hit, ireq_miss;

    assign hit_avail = state == IDLE 
                    | fetch_finish[{ireq_addr.offset, ireq_addr[DATA_BITS-1]}]
                    | {ireq_addr.tag, ireq_addr.index} != {cbus_addr.tag, cbus_addr.index};
    assign ireq_hit = ireq.valid & hit_avail & hit;
    assign ireq_miss = ireq.valid & ~hit;

    //更新meta_ram
    always_comb begin
        meta_w = meta_r;
        if (resetn) begin
            if (state == IDLE & ireq_miss) begin
                for (int i = 0; i < ASSOCIATIVITY; i++) begin
                    if (replace_line == associativity_t'(i)) begin
                        meta_w[i].tag = ireq_addr.tag;
                        meta_w[i].valid = 1'b1;
                    end
                    else begin
                    end
                end
            end
        end
        else begin
            meta_w = '0;
        end
    end

    // always_ff @(posedge clk) begin
    //     if (resetn) begin
    //         if (ireq_hit) begin
    //             for (int i = 0; i < SET_NUM; i++) begin
    //                 plru_ram[i] <= (ireq_addr.index == index_t'(i)) ? plru_new
    //                                                                 : plru_ram[i];
    //             end
    //         end    
    //     end
    //     else begin
    //         plru_ram <= '0;                                            
    //     end
        
    // end

    always_ff @(posedge clk) begin
        if (resetn) begin
            unique case(state)
                IDLE : begin
                    if (ireq_miss) begin
                        state <= FETCH;
                        
                        cbus_addr <= ireq_addr;
                        miss_data_addr <= {replace_line, ireq_addr.index, ireq_addr.offset};
                        
                        part_fetch_finish <= '0;
                        fetch_count <= {ireq_addr.offset, ireq_addr[DATA_BITS-1]};
                    end    
                end
                FETCH : begin
                    if (icresp.ready) begin
                        if (fetch_count[0])  begin
                            miss_data_addr.offset <= miss_data_addr.offset + 1;
                        end

                        for (int i = 0; i < WORD_PER_LINE; i++) begin
                            part_fetch_finish[i] <= (fetch_count == cbus_num_t'(i)) ? 1'b1 : part_fetch_finish[i];
                        end
                        
                        fetch_count <= fetch_count + 1;

                        state <= icresp.last ? IDLE : FETCH;
                    end
                end
                default : begin
                end
            endcase
        end
        else begin
            state <= IDLE;
            cbus_addr <= '0;
            miss_data_addr <= '0;
            part_fetch_finish <= '0;
            fetch_count <= '0;
        end
    end

    always_ff @(posedge clk) begin
        if (resetn) begin
            data_ok_reg <= ireq_hit;
        end
        else begin
            data_ok_reg <= '0;
        end
    end

    RAM_SimpleDualPort #(
        .ADDR_WIDTH(DATA_ADDR_BITS),
        .DATA_WIDTH(DATA_WIDTH),
        .BYTE_WIDTH(BYTE_WIDTH),
        .MEM_TYPE(0),
	    .READ_LATENCY(1)
    ) data_ram(
        .clk, 
        
        .raddr(data_addr), 
        .rdata(data_r),
        
        .en(port_2_en),
        .waddr(port_2_addr),
        .strobe(port_2_wen),
        .wdata(port_2_data_w)
    );

    //DBus
    assign iresp.addr_ok = ireq_hit;
    assign iresp.data_ok = data_ok_reg;
    assign iresp.data = data_r;

    //CBus
    assign icreq.valid = state != IDLE;     
    assign icreq.is_write = 0;  
    assign icreq.size = MSIZE4;      
    assign icreq.addr = cbus_addr;      
    assign icreq.strobe = 0;   
    assign icreq.data = 0;      
    assign icreq.len = MLEN16;  


    `UNUSED_OK({clk, resetn, ireq, icresp});

endmodule

`endif
