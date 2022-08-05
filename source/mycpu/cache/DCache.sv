`ifndef __DCACHE_SV
`define __DCACHE_SV

`include "common.svh"
`ifdef VERILATOR

`endif 
module DCache (
    input logic clk, resetn,

    input  dbus_req_t  dreq_1,
    input logic dreq_1_is_uncached,
    input  dbus_req_t  dreq_2,
    input logic dreq_2_is_uncached,
    output dbus_resp_t dresp,
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
    localparam TAG_BITS = 28 - INDEX_BITS - OFFSET_BITS - DATA_BITS; 

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
        logic dreq_en;
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
        IDLE, FETCH_1, WRITEBACK_1, FETCH_2, WRITEBACK_2, UNCACHE_1, UNCACHE_2
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

    //process
    addr_t process_dreq_1_addr, process_dreq_2_addr;
    dbus_req_t process_dreq_1, process_dreq_2;
    meta_t process_meta_r_1, process_meta_r_2;

    //state
    state_t state;

    //FETCH & WRITEBACK
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
    logic index_equal;
    plru_t [SET_NUM-1 : 0] plru, plru_new;
    associativity_t process_replace_line_1, process_replace_line_2; //process

    //判断hit
    logic hit_1, hit_2;
    logic [ASSOCIATIVITY-1:0] hit_1_bits, hit_2_bits;
    associativity_t hit_line_1, hit_line_2;

    //hit & miss
    logic cache_hit_1, cache_hit_2;
    logic dreq_en;

    reg_t process_hit;
    logic en;

    logic process_cache_hit_1, process_cache_hit_2;

    logic process_dreq_1_is_uncached, process_dreq_2_is_uncached;
    logic uncache_1_flag, uncache_2_flag;

    //w_to_w  w_to_r
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
    state_t finish_state;
    logic finish, finish_reg;

    associativity_t replace_line_1_reg, replace_line_2_reg;

    //uncache_data 寄存器
    word_t uncached_data_1, uncached_data_2;


    //FSM
    logic cache_dirty_1, cache_dirty_2;
    logic fetch_1_end, fetch_2_end, writeback_1_end, writeback_2_end, uncache_1_end, uncache_2_end;

    word_t data_1, data_2;

    //防止重复FETCH
    logic same_line;


    //第一阶段读meta, 第二阶段写meta
    assign dreq_1_addr = dreq_1.addr;
    assign dreq_2_addr = dreq_2.addr;
    assign meta_en = (~resetn|state==FETCH_1|state==FETCH_2) ? 1'b1 : 0;
    assign meta_w_addr = resetn ? ((state==FETCH_2) ? process_dreq_2_addr.index
                                                    : process_dreq_1_addr.index)
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
                    meta_w = process_meta_r_1;
                    for (int i = 0; i < ASSOCIATIVITY; i++) begin
                        if (process_replace_line_1 == associativity_t'(i)) begin
                            meta_w[i].tag = process_dreq_1_addr.tag;
                            meta_w[i].valid = 1'b1;
                        end
                        else begin
                        end
                    end
                    
                end
                FETCH_2: begin
                    meta_w = process_meta_r_2;
                    for (int i = 0; i < ASSOCIATIVITY; i++) begin
                        if (process_replace_line_2 == associativity_t'(i)) begin
                            meta_w[i].tag = process_dreq_2_addr.tag;
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
        assign hit_1_bits[i] = meta_r_1[i].valid & meta_r_1[i].tag == dreq_1_addr.tag;
    end
    assign hit_1 = |hit_1_bits;
    always_comb begin
        hit_line_1 = 0;
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            hit_line_1 |= hit_1_bits[i] ? associativity_t'(i) : 0;
        end
    end

    for (genvar i = 0; i < ASSOCIATIVITY; i++) begin
        assign hit_2_bits[i] = meta_r_2[i].valid & meta_r_2[i].tag == dreq_2_addr.tag;
    end
    assign hit_2 = |hit_2_bits;
    always_comb begin
        hit_line_2 = 0;
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            hit_line_2 |= hit_2_bits[i] ? associativity_t'(i) : 0;
        end
    end
    
    assign cache_hit_1 = ~dreq_1_is_uncached & hit_1;
    assign cache_hit_2 = ~dreq_2_is_uncached & hit_2;
    assign dreq_en = (~dreq_1.valid|cache_hit_1) & (~dreq_2.valid|cache_hit_2);


    always_ff @(posedge clk) begin
        if (resetn) begin
            if (en & ~dreq_en) begin
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
                process_hit.hit_1 <= hit_1;
                process_hit.hit_2 <= hit_2;
                process_hit.hit_line_1 <= hit_line_1;
                process_hit.hit_line_2 <= hit_line_2;
                process_hit.dreq_en <= dreq_en;
                process_dreq_1 <= dreq_1;
                process_dreq_2 <= dreq_2;
                process_meta_r_1 <= meta_r_1;
                process_meta_r_2 <= meta_r_2;   
                process_dreq_1_is_uncached <= dreq_1_is_uncached;
                process_dreq_2_is_uncached <= dreq_2_is_uncached; 
            end
            
        end
        else begin
            process_hit <= '0;
            process_dreq_1 <= '0;
            process_dreq_2 <= '0;
            process_meta_r_1 <= '0;
            process_meta_r_2 <= '0; 
            process_dreq_1_is_uncached <= '0;
            process_dreq_2_is_uncached <= '0; 
        end
    end



    //PLRU 
    assign process_dreq_1_addr = process_dreq_1.addr;
    assign process_dreq_2_addr = process_dreq_2.addr;
    assign process_cache_hit_1 = process_hit.hit_1 & process_dreq_1.valid & ~process_dreq_1_is_uncached;
    assign process_cache_hit_2 = process_hit.hit_2 & process_dreq_2.valid & ~process_dreq_2_is_uncached;

    
    assign index_equal = process_dreq_1_addr.index==process_dreq_2_addr.index;
    assign process_replace_line_1 = (index_equal & process_hit.hit_2) ? ~process_hit.hit_line_2 : plru[process_dreq_1_addr.index];
    assign process_replace_line_2 = (index_equal & process_hit.hit_1) ? ~process_hit.hit_line_1 : plru[process_dreq_2_addr.index];
                                        
    always_comb begin
        plru_new = plru;
        for (int i = 0; i < SET_NUM; i++) begin         
            if (process_cache_hit_1) begin
                plru_new[i] = process_dreq_1_addr.index == index_t'(i) ? ~process_hit.hit_line_1 : plru[i];
            end
            else if (state==FETCH_1 & dcresp.last) begin
                plru_new[i] = process_dreq_1_addr.index == index_t'(i) ? ~process_replace_line_1 : plru[i];
            end

            if (process_cache_hit_2) begin
                plru_new[i] = process_dreq_2_addr.index == index_t'(i) ? ~process_hit.hit_line_2 : plru[i];
            end
            else if (state==FETCH_2 & dcresp.last) begin
                plru_new[i] = process_dreq_2_addr.index == index_t'(i) ? ~process_replace_line_2 : plru[i];
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
                replace_line_1_reg <= process_replace_line_1;
            end
            if (state==FETCH_2 & dcresp.last) begin
                replace_line_2_reg <= process_replace_line_2;
            end
            else if (same_line & dcresp.last) begin
                replace_line_2_reg <= process_replace_line_1;
            end
        end
        else begin
            replace_line_1_reg <= '0;
            replace_line_2_reg <= '0;
        end
    end


    //dirty
    always_comb begin
        cache_dirty_new = cache_dirty;
        for (int i = 0; i < ASSOCIATIVITY*SET_NUM; i++) begin
            unique case (state)
                IDLE: begin
                    if (process_cache_hit_1 & |process_dreq_1.strobe) begin
                        cache_dirty_new[i] = ({process_hit.hit_line_1, process_dreq_1_addr.index} == dirty_t'(i)) ? 1'b1 : cache_dirty[i];
                    end
                    if (process_cache_hit_2 & |process_dreq_2.strobe) begin
                        cache_dirty_new[i] = ({process_hit.hit_line_2, process_dreq_2_addr.index} == dirty_t'(i)) ? 1'b1 : cache_dirty[i];
                    end
                end

                FETCH_1: begin
                    cache_dirty_new[i] = ({process_replace_line_1, process_dreq_1_addr.index} == dirty_t'(i)) ? (|process_dreq_1.strobe ? 1'b1 : '0) : cache_dirty[i];
                end
            
                FETCH_2: begin
                    cache_dirty_new[i] = ({process_replace_line_2, process_dreq_2_addr.index} == dirty_t'(i)) ? (|process_dreq_2.strobe ? 1'b1 : '0) : cache_dirty[i];
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


    
    assign addr_same = (process_dreq_1_addr[31:2] == process_dreq_2_addr[31:2]) & (process_dreq_1.valid & process_dreq_2.valid) & (~process_dreq_1_is_uncached & ~process_dreq_2_is_uncached);


    //W -> W
    assign w_to_w = addr_same & |process_dreq_1.strobe & |process_dreq_2.strobe;
    assign w_to_w_data = (get_mask(process_dreq_2.strobe)
                        & process_dreq_2.data)
                        | (get_mask(process_dreq_1.strobe ^ process_dreq_2.strobe)
                        & process_dreq_1.data);


    //W -> R
    assign w_to_r = addr_same & |process_dreq_1.strobe & ~|process_dreq_2.strobe;
    always_ff @(posedge clk) begin
        if (resetn) begin
            w_to_r_reg <= w_to_r;

            w_to_r_data <= process_dreq_1.data;
            w_to_r_strobe <= process_dreq_1.strobe;
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

    

    assign finish_state = (process_dreq_2.valid & process_dreq_2_is_uncached) ? UNCACHE_2
                            : (process_dreq_2.valid & ~process_dreq_2_is_uncached & ~process_hit.hit_2 & ~same_line) ? FETCH_2
                            : (process_dreq_1.valid & process_dreq_1_is_uncached) ? UNCACHE_1 : FETCH_1;
    assign finish = state==finish_state & dcresp.last;
    

    always_ff @(posedge clk) begin
        if (resetn) begin
            finish_reg <= finish;
        end
        else begin
            finish_reg <= '0;
        end
    end


    //Port 1 : dreq_1 
    assign port_1_en = (process_hit.dreq_en | finish_reg) & ~w_to_w & ~process_dreq_1_is_uncached;       
    assign port_1_wen = process_dreq_1.strobe;                    
    assign port_1_addr.line = process_hit.hit_1 ? process_hit.hit_line_1 : replace_line_1_reg;   
    assign port_1_addr.index = process_dreq_1_addr.index;   
    assign port_1_addr.offset = process_dreq_1_addr.offset;                   
    assign port_1_data_w = process_dreq_1.data;
                                  

    //Port 2 : dreq_2 & cbus
    assign port_2_en = (state==IDLE) ? ((process_hit.dreq_en | finish_reg) & ~process_dreq_2_is_uncached) : 1;
    assign port_2_wen = (state==IDLE) ? (w_to_w ? (process_dreq_1.strobe | process_dreq_2.strobe) : process_dreq_2.strobe)
                                      : (state==FETCH_1|state==FETCH_2) ? {BYTE_PER_DATA{1'b1}} : '0;
    assign port_2_addr = (state==IDLE) ? (process_hit.hit_2 ? {process_hit.hit_line_2, process_dreq_2_addr.index, process_dreq_2_addr.offset} 
                                                            : {replace_line_2_reg, process_dreq_2_addr.index, process_dreq_2_addr.offset})
                                       : miss_addr;
    assign port_2_data_w = (state==IDLE) ? (w_to_w ? w_to_w_data : process_dreq_2.data)
                                         : dcresp.data;



    assign cache_dirty_1 = (cache_dirty[{process_replace_line_1, process_dreq_1_addr.index}] & process_meta_r_1[process_replace_line_1].valid);
    assign cache_dirty_2 = (cache_dirty[{process_replace_line_2, process_dreq_2_addr.index}] & process_meta_r_2[process_replace_line_2].valid); 


    assign same_line = process_dreq_1_addr[31:OFFSET_BITS+DATA_BITS]==process_dreq_2_addr[31:OFFSET_BITS+DATA_BITS] & process_dreq_1.valid & ~process_dreq_1_is_uncached;


    //FSM
    always_ff @(posedge clk) begin
        if (resetn) begin
            if (~en) begin
                unique case (state)
                    IDLE: begin
                        if (process_dreq_1.valid & process_dreq_1_is_uncached & ~uncache_1_end) begin
                            state <= UNCACHE_1;
                        end
                        else if (process_dreq_1.valid & ~process_hit.hit_1 & ~process_dreq_1_is_uncached & ~fetch_1_end) begin
                            state <= (cache_dirty_1 & ~writeback_1_end) ? WRITEBACK_1 : FETCH_1;
                            miss_addr <= {process_replace_line_1, process_dreq_1_addr.index, process_dreq_1_addr.offset};
                            offset_count <= process_dreq_1_addr.offset;
                        end
                        else if (process_dreq_2.valid & process_dreq_2_is_uncached & ~uncache_2_end) begin
                            state <= UNCACHE_2;
                        end
                        else if (process_dreq_2.valid & ~process_dreq_2_is_uncached & ~process_hit.hit_2 & ~fetch_2_end & ~same_line) begin
                            state <= (cache_dirty_2 & ~writeback_2_end) ? WRITEBACK_2 : FETCH_2;
                            miss_addr <= {process_replace_line_2, process_dreq_2_addr.index, process_dreq_2_addr.offset};
                            offset_count <= process_dreq_2_addr.offset;
                        end
                        else begin
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
                            miss_addr.offset <= process_dreq_1_addr.offset;  
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
                            miss_addr.offset <= process_dreq_2_addr.offset;  
                        end

                        delay_counter <= 1'b1;
                    end

                    UNCACHE_1: begin
                        state  <= dcresp.last ? IDLE : UNCACHE_1; 
                    end

                    UNCACHE_2: begin
                        state  <= dcresp.last ? IDLE : UNCACHE_2; 
                    end

                    default: begin   
                    end
                endcase  
            end
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



    always_ff @(posedge clk) begin
        if (resetn) begin
            if (finish_reg) begin
                fetch_1_end <= '0;
                writeback_1_end <= '0;
                fetch_2_end <= '0;
                writeback_2_end <= '0;
                uncache_1_end <= '0;
                uncache_2_end <= '0;
            end
            else begin
                fetch_1_end <= state==FETCH_1 ? 1'b1 : fetch_1_end;
                writeback_1_end <= state==WRITEBACK_1 ? 1'b1 : writeback_1_end;
                fetch_2_end <= state==FETCH_2 ? 1'b1 : fetch_2_end;
                writeback_2_end <= state==WRITEBACK_2 ? 1'b1 : writeback_2_end;
                uncache_1_end <= state==UNCACHE_1 ? 1'b1 : uncache_1_end;
                uncache_2_end <= state==UNCACHE_2 ? 1'b1 : uncache_2_end;
            end
        end
        else begin
            fetch_1_end <= '0;
            writeback_1_end <= '0;
            fetch_2_end <= '0;
            writeback_2_end <= '0;
            uncache_1_end <= '0;
            uncache_2_end <= '0;
        end
    end


    //Cbus
    always_comb begin
        cbus_addr = '0;
        unique case (state)
            FETCH_1: begin
                cbus_addr = process_dreq_1_addr;
            end

            WRITEBACK_1: begin
                cbus_addr = process_dreq_1_addr;
                cbus_addr.tag = process_meta_r_1[process_replace_line_1].tag;
            end

            FETCH_2: begin
                cbus_addr = process_dreq_2_addr;
            end

            WRITEBACK_2: begin
                cbus_addr = process_dreq_2_addr;
                cbus_addr.tag = process_meta_r_2[process_replace_line_2].tag;
            end

            UNCACHE_1: begin
                cbus_addr = process_dreq_1_addr;
            end

            UNCACHE_2: begin
                cbus_addr = process_dreq_2_addr;
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
            data_ok_reg <= en;
        end
        else begin
            data_ok_reg <= '0;
        end
    end

    always_ff @(posedge clk) begin
        if (resetn) begin
            if (state==UNCACHE_1 & dcresp.last) begin
                uncached_data_1 <= dcresp.data;
            end    
        end
        else begin
            uncached_data_1 <= '0;
        end
    end

    always_ff @(posedge clk) begin
        if (resetn) begin
            if (state==UNCACHE_2 & dcresp.last) begin
                uncached_data_2 <= dcresp.data;
            end    
        end
        else begin
            uncached_data_2 <= '0;
        end
    end

    always_ff @(posedge clk) begin
        if (resetn) begin
            uncache_1_flag <= process_dreq_1_is_uncached;
            uncache_2_flag <= process_dreq_2_is_uncached;
        end 
        else begin
            uncache_1_flag <= '0;
            uncache_2_flag <= '0;
        end   
    end

    //DBus 
    assign dresp.addr_ok = en;
    assign dresp.data_ok = data_ok_reg;
    assign data_1 = uncache_1_flag ? uncached_data_1 : port_1_data_r;
    assign data_2 = uncache_2_flag ? uncached_data_2
                    : w_to_r_reg ? w_to_r_resp_data : port_2_data_r;
    assign dresp.data = {data_2, data_1};



    //CBus
    assign dcreq.valid = state==FETCH_1 | state==FETCH_2 | (state==WRITEBACK_1 & delay_counter) | (state==WRITEBACK_2 & delay_counter) | state==UNCACHE_1 | state==UNCACHE_2;     
    assign dcreq.is_write = state==WRITEBACK_1 | state==WRITEBACK_2 | (state==UNCACHE_1 & |process_dreq_1.strobe) | (state==UNCACHE_2 & |process_dreq_2.strobe);  
    assign dcreq.size = state==UNCACHE_1 ? process_dreq_1.size
                        : state==UNCACHE_2 ? process_dreq_2.size : MSIZE4;      
    assign dcreq.addr = cbus_addr;      
    assign dcreq.strobe = state==UNCACHE_1 ? process_dreq_1.strobe
                        : state==UNCACHE_2 ? process_dreq_2.strobe : {BYTE_PER_DATA{1'b1}};    
    assign dcreq.data = state==UNCACHE_1 ? process_dreq_1.data
                        : state==UNCACHE_2 ? process_dreq_2.data : buffer[offset_count];    
    assign dcreq.len = (state==UNCACHE_1 | state==UNCACHE_2) ? MLEN1 : MLEN16;  

    `UNUSED_OK({clk, resetn, dreq_1, dreq_2, dcresp});
endmodule

`endif