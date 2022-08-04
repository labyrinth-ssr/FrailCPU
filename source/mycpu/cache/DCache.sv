`ifndef __DCACHE_SV
`define __DCACHE_SV

`include "common.svh"
`ifdef VERILATOR

`include "../plru.sv"
`endif 
module DCache (
    input logic clk, resetn,

    input  dbus_req_t  dreq_1,
    output dbus_resp_t dresp_1,
    input  dbus_req_t  dreq_2,
    output dbus_resp_t dresp_2,
    output cbus_req_t  dcreq,
    input  cbus_resp_t dcresp
);
    //16KB 2路组相联 1行16个data
    //1 + 7 + 4 + 2
    localparam DATA_PER_LINE = 16;
    localparam ASSOCIATIVITY = 2;
    localparam SET_NUM = 128;

    localparam BYTE_WIDTH = 8;
    localparam BYTE_PER_DATA = 4;
    localparam DATA_WIDTH = BYTE_WIDTH * BYTE_PER_DATA;

    localparam DATA_BITS = $clog2(BYTE_PER_DATA);
    localparam OFFSET_BITS = $clog2(DATA_PER_LINE);
    localparam ASSOCIATIVITY_BITS = $clog2(ASSOCIATIVITY);
    localparam INDEX_BITS = $clog2(SET_NUM);
    localparam TAG_BITS = 32 - INDEX_BITS - OFFSET_BITS - DATA_BITS; 

    localparam DATA_ADDR_BITS = ASSOCIATIVITY_BITS + INDEX_BITS + OFFSET_BITS;

    localparam type align_t = logic [DATA_BITS-1:0];
    localparam type offset_t = logic [OFFSET_BITS-1:0];
    localparam type associativity_t = logic [ASSOCIATIVITY_BITS-1:0];
    localparam type index_t = logic [INDEX_BITS-1:0];
    localparam type tag_t = logic [TAG_BITS-1:0];

    localparam type dirty_t = logic [INDEX_BITS+ASSOCIATIVITY_BITS-1:0];

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

    localparam type reg_t = struct packed {
        logic hit_1;
        logic hit_2;
        logic dreq_hit_1;
        logic dreq_hit_2;
        logic dreq_hit;
        associativity_t hit_line_1;
        associativity_t hit_line_2;
    };

    //meta_ram
    typedef struct packed {
        logic valid;
        tag_t tag;
    } info_t;

    localparam type meta_t = info_t [ASSOCIATIVITY-1:0];

    localparam type buffer_t = word_t [DATA_PER_LINE-1:0];
    localparam type record_t = logic [DATA_PER_LINE-1:0];

    localparam type plru_t = logic [ASSOCIATIVITY-2:0];

    localparam type state_t = enum logic[2:0] {
        IDLE, FETCH_1, WRITEBACK_1, FETCH_2, WRITEBACK_2
    };

    function word_t get_mask(input strobe_t strobe);
        return {{8{strobe[3]}}, {8{strobe[2]}}, {8{strobe[1]}}, {8{strobe[0]}}};
    endfunction















    //for meta reset
    index_t reset_counter;
    always_ff @(posedge clk) begin
        reset_counter <= reset_counter + 1;
    end

    //stage1
    addr_t dreq_1_addr, dreq_2_addr;

    //stage2
    addr_t stage2_dreq_1_addr, stage2_dreq_2_addr;
    dbus_req_t stage2_dreq_1, stage2_dreq_2;
    meta_t stage2_meta_r_1, stage2_meta_r_2;

    //state
    state_t state;

    //FETCH && WRITEBACK
    data_addr_t miss_addr;
    addr_t cbus_addr;

    //buffer
    buffer_t buffer;
    offset_t buffer_offset; //DCache -> Buffer
    offset_t offset_count; //Buffer -> 内存
    logic delay_counter; //WRITEBACK DCache 读延迟

    //dota_ok 延迟
    logic data_ok_reg;
    
    //meta_ram
    meta_t meta_ram [SET_NUM-1:0];
    logic meta_en;
    index_t meta_w_addr;
    meta_t meta_w;
    index_t meta_r_addr_1, meta_r_addr_2;
    meta_t meta_r_1, meta_r_2;

    //cache_dirty
    logic [ASSOCIATIVITY*SET_NUM-1:0] cache_dirty, cache_dirty_new;

    //plru
    plru_t [SET_NUM-1 : 0] plru, plru_new;
    associativity_t replace_line_1, replace_line_2; //stage2

    //判断hit
    logic hit_1, hit_2;
    logic [ASSOCIATIVITY-1:0] hit_1_bits, hit_2_bits;
    associativity_t hit_line_1, hit_line_2;

    //hit && miss
    logic dreq_hit_1, dreq_hit_2;
    logic dreq_hit;
    logic miss_1;
    logic miss_2;
    logic miss;

    reg_t hit_reg;
    logic en;

    //DCache_1 -> DCache_2
    logic stall_finish_1;
    logic stall_finish_2;

    logic addr_same;
    logic w_to_w;
    word_t w_to_w_data;

    logic w_to_r;
    logic w_to_r_reg;
    word_t w_to_r_data;
    strobe_t w_to_r_strobe;

    //Port1
    logic port_1_en;
    strobe_t port_1_wen;
    data_addr_t port_1_addr;
    word_t port_1_data_w, port_1_data_r;

    //Port2
    logic port_2_en;
    strobe_t port_2_wen;
    data_addr_t port_2_addr;
    word_t port_2_data_w, port_2_data_r;

    //FETCH结束,下一周期addr_ok
    logic finish, finish_reg;

    //
    associativity_t replace_line_1_reg, replace_line_2_reg;









    //第一阶段读meta, 第二阶段(FETCH时)写meta
    assign dreq_1_addr = dreq_1.addr;
    assign dreq_2_addr = dreq_2.addr;
    assign meta_en = (~resetn|state==FETCH_1|state==FETCH_2) ? 1'b1 : 0;
    assign meta_w_addr = resetn ? ((state==FETCH_2) ? dreq_2_addr.index
                                                    : dreq_1_addr.index)
                                : reset_counter[INDEX_BITS-1:0];
    always_ff @(posedge clk) begin
        if (meta_en) begin
            meta_ram[meta_w_addr] <= meta_w;
        end
    end
    assign meta_r_addr_1 = dreq_1_addr.index;
    assign meta_r_addr_2 = dreq_2_addr.index;
    assign meta_r_1 = meta_ram[meta_r_addr_1];
    assign meta_r_2 = meta_ram[meta_r_addr_2];
    //meta_w
    always_comb begin
        meta_w = '0;
        if (resetn) begin
            unique case (state)
                FETCH_1: begin
                    meta_w = stage2_meta_r_1;
                    for (int i = 0; i < ASSOCIATIVITY; i++) begin
                        if (replace_line_1 == associativity_t'(i)) begin
                            meta_w[i].tag = stage2_dreq_1_addr.tag;
                            meta_w[i].valid = 1'b1;
                        end
                        else begin
                        end
                    end
                    
                end
                FETCH_2: begin
                    meta_w = stage2_meta_r_2;
                    for (int i = 0; i < ASSOCIATIVITY; i++) begin
                        if (replace_line_2 == associativity_t'(i)) begin
                            meta_w[i].tag = stage2_dreq_2_addr.tag;
                            meta_w[i].valid = 1'b1;
                        end
                        else begin
                        end
                    end
                end
                
                default: begin   
                end
            endcase    
        end
        else begin
        end
    end













    //stage1 计算hit 
    for (genvar i = 0; i < ASSOCIATIVITY; i++) begin
        assign hit_1_bits[i] = meta_r_1[i].valid && meta_r_1[i].tag == dreq_1_addr.tag;
    end
    assign hit_1 = |hit_1_bits;
    always_comb begin
        hit_line_1 = 0;
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            hit_line_1 |= hit_1_bits[i] ? associativity_t'(i) : 0;
        end
    end

    for (genvar i = 0; i < ASSOCIATIVITY; i++) begin
        assign hit_2_bits[i] = meta_r_2[i].valid && meta_r_2[i].tag == dreq_2_addr.tag;
    end
    assign hit_2 = |hit_2_bits;
    always_comb begin
        hit_line_2 = 0;
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            hit_line_2 |= hit_2_bits[i] ? associativity_t'(i) : 0;
        end
    end
    
    assign dreq_hit_1 = dreq_1.valid & hit_1;
    assign dreq_hit_2 = dreq_2.valid & hit_2;
    assign dreq_hit = (dreq_hit_1 & dreq_hit_2) | (dreq_hit_1 & ~dreq_2.valid);
    assign miss_1 = dreq_1.valid & ~hit_1 & ((dreq_2.valid & hit_2) | ~dreq_2.valid);
    assign miss_2 = dreq_2.valid & ~hit_2;
    assign miss = (dreq_1.valid & ~hit_1) | (dreq_2.valid & ~hit_2);






















    /* DCache_1 -> DCache_2 ************** */
    // assign stall_finish_1 = miss_1 & state == FETCH_1 & dcresp.last;
    // assign stall_finish_2 = miss_2 & state == FETCH_2 & dcresp.last;

    always_ff @(posedge clk) begin
        if (resetn) begin
            if (en & miss) begin
                en <= '0; 
            end
            else if (~en & finish) begin
                en <= 1'b1;
            end    
        end
        else begin
            en <= 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (resetn) begin
            if (en) begin
                hit_reg.hit_1 <= hit_1;
                hit_reg.hit_2 <= hit_2;
                hit_reg.hit_line_1 <= hit_line_1;
                hit_reg.hit_line_2 <= hit_line_2;
                hit_reg.dreq_hit_1 <= dreq_hit_1;
                hit_reg.dreq_hit_2 <= dreq_hit_2;
                hit_reg.dreq_hit <= dreq_hit;
                stage2_dreq_1 <= dreq_1;
                stage2_dreq_2 <= dreq_2;
                stage2_meta_r_1 <= meta_r_1;
                stage2_meta_r_2 <= meta_r_2;    
            end
            
        end
        else begin
            hit_reg <= '0;
            stage2_dreq_1 <= '0;
            stage2_dreq_2 <= '0;
            stage2_meta_r_1 <= '0;
            stage2_meta_r_2 <= '0; 
        end
    end
    /* ********************** */















    
    assign stage2_dreq_1_addr = stage2_dreq_1.addr;
    assign stage2_dreq_2_addr = stage2_dreq_2.addr;

    //stage2 PLRU 
    assign replace_line_1 = (stage2_dreq_1_addr.index==stage2_dreq_2_addr.index & hit_reg.dreq_hit_2) ? ~hit_reg.hit_line_2
                                                                                                      : plru[stage2_dreq_1_addr.index];
    assign replace_line_2 = (stage2_dreq_1_addr.index!=stage2_dreq_2_addr.index) ? plru[stage2_dreq_2_addr.index]
                                                                                 : (hit_reg.dreq_hit_1) ? ~hit_reg.hit_line_1
                                                                                                       : ~plru[stage2_dreq_1_addr.index];
    always_comb begin
        plru_new = plru;
        for (int i = 0; i < SET_NUM; i++) begin
            if (stage2_dreq_1_addr.index == index_t'(i)) begin
                plru_new[i] = hit_reg.dreq_hit_1 ? ~hit_reg.hit_line_1
                                                 : (state==FETCH_1 & dcresp.last) ? ~replace_line_1
                                                                                  : plru[i];
            end
            if (stage2_dreq_2_addr.index == index_t'(i)) begin
                plru_new[i] = hit_reg.dreq_hit_2 ? ~hit_reg.hit_line_2
                                                 : (state==FETCH_2 & dcresp.last) ? ~replace_line_2
                                                                                  : plru[i];
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

    always_ff @(posedge clk) begin
        if (resetn) begin
            if (state==FETCH_1 & dcresp.last) begin
                replace_line_1_reg <= replace_line_1;
            end
            if (state==FETCH_2 & dcresp.last) begin
                replace_line_2_reg <= replace_line_2;
            end
        end
        else begin
            plru <= '0;
        end
    end
    /* ********************** */

















    //stage2 dirty
    always_comb begin
        cache_dirty_new = cache_dirty;
        for (int i = 0; i < ASSOCIATIVITY*SET_NUM; i++) begin
            unique case (state)
                IDLE: begin
                    if (hit_reg.dreq_hit_1 & |stage2_dreq_1.strobe) begin
                        cache_dirty_new[i] = ({hit_reg.hit_line_1, stage2_dreq_1_addr.index} == dirty_t'(i)) ? 1'b1 : cache_dirty[i];
                    end
                    if (hit_reg.dreq_hit_2 & |stage2_dreq_2.strobe) begin
                        cache_dirty_new[i] = ({hit_reg.hit_line_2, stage2_dreq_2_addr.index} == dirty_t'(i)) ? 1'b1 : cache_dirty[i];
                    end
                end

                FETCH_1: begin
                    cache_dirty_new[i] = ({replace_line_1, dreq_1_addr.index} == dirty_t'(i)) ? (|stage2_dreq_1.strobe ? 1'b1 : '0)
                                                                                              : cache_dirty[i];
                end
            
                FETCH_2: begin
                    cache_dirty_new[i] = ({replace_line_2, dreq_2_addr.index} == dirty_t'(i)) ? (|stage2_dreq_2.strobe ? 1'b1 : '0) 
                                                                                              : cache_dirty[i];
                end

                default: begin   
                end
            endcase
        end     
    end
    always_ff @(posedge clk) begin
        if (resetn) begin
            cache_dirty <= cache_dirty_new;
        end 
        else begin
            cache_dirty <= '0;
        end
    end

















    
    assign addr_same = (stage2_dreq_2_addr[31:2] == stage2_dreq_2_addr[31:2]) & (stage2_dreq_1.valid & stage2_dreq_2.valid);

    //W -> W
    assign w_to_w = addr_same & |stage2_dreq_1.strobe & |stage2_dreq_2.strobe;
    assign w_to_w_data = (get_mask(stage2_dreq_2.strobe)
                        & stage2_dreq_2.data)
                        | (get_mask(stage2_dreq_1.strobe ^ stage2_dreq_2.strobe)
                        & stage2_dreq_1.data);

    //W -> R
    assign w_to_r = addr_same & |stage2_dreq_1.strobe & ~|stage2_dreq_2.strobe;
    always_ff @(posedge clk) begin
        if (resetn) begin
            w_to_r_reg <= w_to_r;

            w_to_r_data <= stage2_dreq_1.data;
            w_to_r_strobe <= stage2_dreq_1.strobe;
        end
        else begin
            w_to_r_reg <= '0;

            w_to_r_data <= '0;
            w_to_r_strobe <= '0;
        end
    end
    word_t w_to_r_resp_data;
    assign w_to_r_resp_data = (get_mask(w_to_r_strobe)
                                & w_to_r_data)
                                | (get_mask(w_to_r_strobe ^ {4{1'b1}})
                                & port_1_data_r);

    























    assign finish = (stage2_dreq_2.valid & ~hit_reg.hit_2) ? (state==FETCH_2 & dcresp.last)
                                                           : (state==FETCH_1 & dcresp.last);
    always_ff @(posedge clk) begin
        if (resetn) begin
            finish_reg <= finish;
        end
        else begin
            finish_reg <= '0;
        end
    end














    //Port 1 : dreq_1 
    assign port_1_en = (hit_reg.dreq_hit | finish_reg) & ~w_to_w;       
    assign port_1_wen = stage2_dreq_1.strobe;                    
    assign port_1_addr.line = hit_reg.dreq_hit_1 ? hit_reg.hit_line_1
                                                 : replace_line_1_reg;   
    assign port_1_addr.index = stage2_dreq_1_addr.index;   
    assign port_1_addr.offset = stage2_dreq_1_addr.offset;                   
    assign port_1_data_w = stage2_dreq_1.data;
                                  

    //Port 2 : dreq_2 & cbus
    assign port_2_en = (state==IDLE) ? (hit_reg.dreq_hit | finish_reg) : 1;
    assign port_2_wen = (state==IDLE) ? (w_to_w ? (stage2_dreq_1.strobe | stage2_dreq_2.strobe) : stage2_dreq_2.strobe)
                                      : (state==FETCH_1|state==FETCH_2) ? {BYTE_PER_DATA{1'b1}}
                                                                        : '0;
    assign port_2_addr = (state==IDLE) ? (hit_reg.dreq_hit_1 ? {hit_reg.hit_line_2, stage2_dreq_2_addr.index, stage2_dreq_2_addr.offset} 
                                                            : {replace_line_2_reg, stage2_dreq_2_addr.index, stage2_dreq_2_addr.offset})
                                       : miss_addr;
    assign port_2_data_w = (state==IDLE) ? (w_to_w ? w_to_w_data : stage2_dreq_2.data)
                                         : dcresp.data;
















    //FSM
    always_ff @(posedge clk) begin
        if (resetn) begin
            unique case (state)
                IDLE: begin
                    if (~finish_reg) begin
                        if (stage2_dreq_1.valid & ~hit_reg.hit_1) begin
                            if (cache_dirty[{replace_line_1, stage2_dreq_1_addr.index}] & stage2_meta_r_1[replace_line_1].valid) begin
                                state <= WRITEBACK_1;
                            end
                            else begin
                                state <= FETCH_1;
                            end
                            miss_addr <= {replace_line_1, stage2_dreq_1_addr.index, stage2_dreq_1_addr.offset};
                            offset_count <= stage2_dreq_1_addr.offset;
                        end

                        else if (hit_reg.hit_1 & stage2_dreq_2.valid & ~hit_reg.hit_2) begin
                            if (cache_dirty[{replace_line_2, stage2_dreq_2_addr.index}] & stage2_meta_r_2[replace_line_2].valid) begin
                                state <= WRITEBACK_2;
                            end
                            else begin
                                state <= FETCH_2;
                            end
                            miss_addr <= {replace_line_2, stage2_dreq_2_addr.index, stage2_dreq_2_addr.offset};
                            offset_count <= stage2_dreq_2_addr.offset;
                        end

                        else begin
                        end
    
                    end
                    
                    delay_counter <= '0;
                end

                FETCH_1: begin
                    if (dcresp.ready) begin
                        state  <= dcresp.last ? IDLE : FETCH_1; 
                        miss_addr.offset <= miss_addr.offset + 1;  
                    end
                end

                WRITEBACK_1: begin
                    if (dcresp.ready) begin
                        state  <= dcresp.last ? FETCH_1 : WRITEBACK_1;
                        offset_count <= offset_count + 1;
                    end

                    miss_addr.offset <= miss_addr.offset + 1;  
                    buffer_offset <= miss_addr.offset;

                    for (int i = 0; i < DATA_PER_LINE; i++) begin
                        buffer[i] <= (buffer_offset == offset_t'(i)) ? port_2_data_r : buffer[i];
                    end
                    
                    if (dcresp.last) begin
                        miss_addr.offset <= dreq_1_addr.offset;  
                    end

                    delay_counter <= 1'b1;
                end

                FETCH_2: begin
                    if (dcresp.ready) begin
                        state  <= dcresp.last ? IDLE : FETCH_2;
                        miss_addr.offset <= miss_addr.offset + 1;  
                    end
                end

                WRITEBACK_2: begin
                    if (dcresp.ready) begin
                        state  <= dcresp.last ? FETCH_2 : WRITEBACK_2;
                        offset_count <= offset_count + 1;
                    end

                    miss_addr.offset <= miss_addr.offset + 1;  
                    buffer_offset <= miss_addr.offset;
                    for (int i = 0; i < DATA_PER_LINE; i++) begin
                        buffer[i] <= (buffer_offset == offset_t'(i)) ? port_2_data_r : buffer[i];
                    end

                    if (dcresp.last) begin
                        miss_addr.offset <= dreq_2_addr.offset;  
                    end

                    delay_counter <= 1'b1;
                end

                default: begin   
                end
            endcase  
        end
        else begin
            state <= IDLE;
            miss_addr <= '0;
            offset_count <= '0;

            delay_counter <= '0;

            buffer_offset <= '0;
            buffer <= '0;
        end
    end

    //Cbus
    always_comb begin
        cbus_addr = '0;
        unique case (state)
            FETCH_1: begin
                cbus_addr = stage2_dreq_1_addr;
            end

            WRITEBACK_1: begin
                cbus_addr = stage2_dreq_1_addr;
                cbus_addr.tag = stage2_meta_r_1[replace_line_1].tag;
            end

            FETCH_2: begin
                cbus_addr = stage2_dreq_2_addr;
            end

            WRITEBACK_2: begin
                cbus_addr = stage2_dreq_2_addr;
                cbus_addr.tag = stage2_meta_r_2[replace_line_2].tag;
            end

            default: begin   
            end
        endcase
    end




















    
    RAM_TrueDualPort #(
        .ADDR_WIDTH(DATA_ADDR_BITS),
        .DATA_WIDTH(DATA_WIDTH),
        .BYTE_WIDTH(BYTE_WIDTH),
        .MEM_TYPE(0),
	    .READ_LATENCY(1)
    ) data_ram(
        .clk, 

        .en_1(port_1_en), 
        .addr_1(port_1_addr), 
        .strobe_1(port_1_wen), 
        .wdata_1(port_1_data_w), 
        .rdata_1(port_1_data_r),

        .en_2(port_2_en),
        .addr_2(port_2_addr),
        .strobe_2(port_2_wen),
        .wdata_2(port_2_data_w),
        .rdata_2(port_2_data_r)
    );






























    always_ff @(posedge clk) begin
        if (resetn) begin
            data_ok_reg <= hit_reg.dreq_hit | finish_reg;
        end
        else begin
            data_ok_reg <= '0;
        end
    end

    //DBus
    assign dresp_1.addr_ok = hit_reg.dreq_hit | finish_reg;
    assign dresp_1.data_ok = data_ok_reg;
    assign dresp_1.data = port_1_data_r;

    assign dresp_2.addr_ok = hit_reg.dreq_hit | finish_reg;
    assign dresp_2.data_ok = data_ok_reg;
    assign dresp_2.data = w_to_r_reg ? w_to_r_resp_data : port_2_data_r;

    //CBus
    assign dcreq.valid = state == FETCH_1 | state == FETCH_2 | (state == WRITEBACK_1 & delay_counter) | (state == WRITEBACK_2 & delay_counter);     
    assign dcreq.is_write = state == WRITEBACK_1 | state == WRITEBACK_2;  
    assign dcreq.size = MSIZE4;      
    assign dcreq.addr = cbus_addr;      
    assign dcreq.strobe = {BYTE_PER_DATA{1'b1}};   
    assign dcreq.data = buffer[offset_count];      
    assign dcreq.len = MLEN16;  

    `UNUSED_OK({clk, resetn, dreq_1, dreq_2, dcresp});
endmodule

`endif