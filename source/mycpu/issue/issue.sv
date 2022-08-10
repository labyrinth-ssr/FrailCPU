`ifndef ISSUE_SV
`define ISSUE_SV


`include "common.svh"
`include "pipes.svh"
`include "cp0_pkg.svh"


module issue(
    input u1 clk,reset,
    input decode_data_t [1:0] dataD ,
    output issue_data_t [1:0] dataI ,
    input word_t [1:0] rd1,rd2,
    output bypass_issue_t [1:0] issue_bypass_out,
    input bypass_output_t [1:0] bypass_inra1,
    input bypass_output_t [1:0] bypass_inra2,
    input u1 flush_que,
    input u1 stallI,stallI_de,
    output u1 overflow,
    output decode_data_t candidate1,
    output u1 issue_en_1,
    output u1 candidate2_invalid,
    input u1 pred_flush_que,
    input u1 jr_predicted,
    input word_t jr_predicted_pc
);
localparam ISSUE_QUEUE_SIZE = 16;
localparam ISSUE_QUEUE_WIDTH = $clog2(ISSUE_QUEUE_SIZE);

localparam type index_t = logic [ISSUE_QUEUE_WIDTH-1:0];
// decode_data_t candidate[1:0];
u1 have_slot;
// decode_data_t issue_queue_even [ISSUE_QUEUE_SIZE-1:0];
// decode_data_t issue_queue_odd [ISSUE_QUEUE_SIZE-1:0];
index_t head_even,head_odd;
index_t tail_even,tail_odd;

decode_data_t rdata_even,rdata_odd,wdata_even,wdata_odd;
u1 even_en,odd_en;

u1 issue_en1,issue_en2;
decode_data_t candidate2;

RAM_SimpleDualPort  #(
    .ADDR_WIDTH(ISSUE_QUEUE_WIDTH),
    .DATA_WIDTH($bits(decode_data_t)),
    .BYTE_WIDTH($bits(decode_data_t))
)issue_queue_even(
    .clk,.en(even_en),
    .raddr(head_even),
    .waddr(tail_even),
    .wdata(wdata_even),
    .rdata(rdata_even),
    .strobe('1)
);

RAM_SimpleDualPort #(
    .ADDR_WIDTH(ISSUE_QUEUE_WIDTH),
    .DATA_WIDTH($bits(decode_data_t)),
    .BYTE_WIDTH($bits(decode_data_t))
)issue_queue_odd(
    .clk,.en(odd_en),
    .raddr(head_odd),
    .waddr(tail_odd),
    .wdata(wdata_odd),
    .rdata(rdata_odd),
    .strobe('1)
);
assign candidate2_invalid=~candidate2.valid;
assign issue_en_1=issue_en1;
function index_t push(index_t tail_in);
    return ~(|tail_in)? 4'd15:tail_in-1;
endfunction
function index_t pop(index_t head_in);
    return ~(|head_in)? 4'd15:head_in-1;
endfunction
function u1 multi_op(control_t ctl);
    return ctl.div||ctl.mul;
endfunction
function u1 odd_larger(index_t odd,index_t even);
    return odd==even;
endfunction
u1 que_empty;
assign que_empty= head_even==tail_even && head_odd==tail_odd;

always_comb begin
    candidate1='0;
    candidate2='0;
    if (odd_larger(head_odd,head_even)&&head_odd!=tail_odd) begin
        candidate1=rdata_odd;
    end else if (~odd_larger(head_odd,head_even)&&head_even!=tail_even) begin
        candidate1=rdata_even;
    end

    if (odd_larger(head_odd,head_even)&&head_even!=tail_even) begin
        candidate2=rdata_even;
    end else if (~odd_larger(head_odd,head_even)&&head_odd!=tail_odd) begin
        candidate2=rdata_odd;
    end
end

assign issue_en1=candidate1.valid&& bypass_inra1[1].valid && bypass_inra2[1].valid && 
(~((candidate1.ctl.jump||candidate1.ctl.branch)&&~(candidate2.valid && bypass_inra1[0].valid && bypass_inra2[0].valid)));

assign have_slot= (candidate1.ctl.branch||candidate1.ctl.jump);

assign issue_en2=candidate2.valid&& bypass_inra1[0].valid && bypass_inra2[0].valid 
&& ~((candidate1.ctl.regwrite&&(candidate1.rdst==candidate2.ra1||candidate1.rdst==candidate2.ra2)&&~have_slot)
        ||(multi_op(candidate1.ctl)&&multi_op(candidate2.ctl))
        ||candidate1.ctl.cp0write
        ||candidate2.ctl.cp0write
        ||~issue_en1||candidate2.ctl.branch||candidate2.ctl.jump
        ||(candidate1.ctl.lowrite&&candidate2.ctl.lotoreg)||(candidate1.ctl.hiwrite&&candidate2.ctl.hitoreg)
        ||(candidate1.ctl.cp0toreg&&candidate2.ctl.cp0toreg)
        ||(candidate1.cp0_ctl.ctype==EXCEPTION||candidate1.cp0_ctl.ctype==ERET)
        ||candidate1.ctl.single_issue
        ||candidate2.ctl.single_issue);

assign overflow= push(tail_odd)==head_odd || push(tail_even)==head_even;

always_comb begin
    {wdata_odd,wdata_even,odd_en,even_en}='0;
    if (~stallI)begin
        if (odd_larger(tail_odd,tail_even)&&dataD[1].valid) begin
            wdata_odd=dataD[1];
            odd_en='1;
        end else if (~odd_larger(tail_odd,tail_even)&&dataD[0].valid) begin
            wdata_odd=dataD[0];
            odd_en='1;
        end

        if (~odd_larger(tail_odd,tail_even)&&dataD[1].valid) begin
            wdata_even=dataD[1];
            even_en='1;
        end else if (odd_larger(tail_odd,tail_even)&&dataD[0].valid) begin
            wdata_even=dataD[0];
            even_en='1;
        end
    end
end

always_ff @(posedge clk) begin
    if (reset||flush_que) begin
        {tail_even,tail_odd}<='0;
    end else if (pred_flush_que) begin
        tail_even<=pop(head_even);
        tail_odd<=pop(head_odd);
    end else if (~stallI)begin
        if (odd_larger(tail_odd,tail_even)&&dataD[1].valid) begin
            // issue_queue_odd[tail_odd]<=dataD[1];
            tail_odd<=push(tail_odd);
        end else if (~odd_larger(tail_odd,tail_even)&&dataD[0].valid) begin
            // issue_queue_odd[tail_odd]<=dataD[0];
            tail_odd<=push(tail_odd);
        end

        if (~odd_larger(tail_odd,tail_even)&&dataD[1].valid) begin
            // issue_queue_even[tail_even]<=dataD[1];
            tail_even<=push(tail_even);
        end else if (odd_larger(tail_odd,tail_even)&&dataD[0].valid) begin
            // issue_queue_even[tail_even]<=dataD[0];
            tail_even<=push(tail_even);
        end
    end
end

    always_ff @(posedge clk) begin
        if (flush_que||reset) begin
            {head_even,head_odd} <= '0;
        end else if (~stallI || (overflow && ~stallI_de)) begin
            if (odd_larger(head_odd,head_even)&&issue_en1||(~odd_larger(head_odd,head_even)&&issue_en2)) begin
                head_odd<=pop(head_odd);
            end
            if (~odd_larger(head_odd,head_even) && issue_en1 || odd_larger(head_odd,head_even)&& issue_en2) begin
                head_even<=pop(head_even);
            end
        end
    end

  assign  issue_bypass_out[1].ra1= candidate1.ra1;
  assign  issue_bypass_out[1].ra2= candidate1.ra2;

  assign  issue_bypass_out[0].ra1= candidate2.ra1;
  assign  issue_bypass_out[0].ra2= candidate2.ra2;

  always_comb begin
        {dataI[1],dataI[0]}='0; 
        if (~que_empty) begin
            if (issue_en1) begin
                dataI[1].ctl=candidate1.ctl;
                dataI[1].pc=candidate1.pc;
                dataI[1].valid=candidate1.valid;
                dataI[1].imm=candidate1.imm;
                dataI[1].ra1=candidate1.ra1;
                dataI[1].ra2=candidate1.ra2;
                dataI[1].rd1=bypass_inra1[1].bypass? bypass_inra1[1].data :rd1[1];
                dataI[1].rd2=bypass_inra2[1].bypass? bypass_inra2[1].data :rd2[1];
                dataI[1].raw_instr=candidate1.raw_instr;
                dataI[1].cp0ra=candidate1.cp0ra;
                dataI[1].rdst=candidate1.rdst;
                dataI[1].i_tlb_exc=candidate1.i_tlb_exc;
                dataI[1].cache_ctl=candidate1.cache_ctl;
                dataI[1].cp0_ctl=candidate1.cp0_ctl;
                dataI[1].pre_b=candidate1.pre_b||jr_predicted;
                dataI[1].pre_pc= jr_predicted? jr_predicted_pc:candidate1.pre_pc;
            end
            if (issue_en2) begin
                    dataI[0].ctl=candidate2.ctl;
                    dataI[0].pc=candidate2.pc;
                    dataI[0].valid=candidate2.valid;
                    dataI[0].imm=candidate2.imm;
                    dataI[0].ra1=candidate2.ra1;
                    dataI[0].ra2=candidate2.ra2;
                    dataI[0].rd1=bypass_inra1[0].bypass? bypass_inra1[0].data :rd1[0];
                    dataI[0].rd2=bypass_inra2[0].bypass? bypass_inra2[0].data :rd2[0];
                    dataI[0].raw_instr=candidate2.raw_instr;
                    dataI[0].cp0ra=candidate2.cp0ra;
                    dataI[0].cache_ctl=candidate2.cache_ctl;
                    dataI[0].rdst=candidate2.rdst;
                    dataI[0].i_tlb_exc=candidate2.i_tlb_exc;
                    dataI[0].cp0_ctl=candidate2.cp0_ctl;
                    dataI[0].pre_b='0;
                    dataI[0].pre_pc='0;
                    if (have_slot) begin
                        dataI[0].is_slot='1;
                    end
                end
        end
    end

    // always_comb begin
//     // have_slot='0;
//     issue_en[0]=candidate2.valid && bypass_inra1[0].valid && bypass_inra2[0].valid;
//     issue_en[1]=bypass_inra1[1].valid && bypass_inra2[1].valid&& (~((candidate1.ctl.jump||candidate1.ctl.branch)&&~issue_en[0]));
//     have_slot=(candidate1.ctl.branch||candidate1.ctl.jump)&&issue_en[1];
//      if ((candidate1.ctl.regwrite&&(candidate1.rdst==candidate2.ra1||candidate1.rdst==candidate2.ra2)&&~have_slot)
//         ||(multi_op(candidate1.ctl.op)&&multi_op(candidate2.ctl.op))
//         ||(candidate1.ctl.cp0write&&candidate2.ctl.cp0write)||~issue_en[1]||candidate2.ctl.branch||candidate2.ctl.jump
//         ||(candidate1.ctl.lowrite&&candidate2.ctl.lotoreg)||(candidate1.ctl.hiwrite&&candidate2.ctl.hitoreg)
//         ||(candidate1.ctl.cp0write&&candidate2.ctl.cp0toreg)||(candidate1.ctl.cp0toreg&&candidate2.ctl.cp0toreg)
//         ||(candidate1.cp0_ctl.ctype==EXCEPTION||candidate1.cp0_ctl.ctype==ERET)) begin
//         issue_en[0]='0;
//     end
// end

// assign candidate1=odd_larger? issue_queue[head_odd]:issue_queue[head_even];
// assign candidate2=odd_larger? issue_queue[head_odd]:issue_queue[head_even];
// always_comb begin
//     candidate2='0;
//     if (que_empty) begin
//         candidate2=dataD[0];
//     end else if (pop(head)==tail) begin
//         candidate2=dataD[1];
//     end else begin
//         candidate2=issue_queue[pop(head)];
//     end
// end
// assign 

//cp0两个写，不能同时发射（因为可能有wa不同）
//cp0两个读，不可同时
//一读一写，若读在写前，可以；读在写后，不行（可能是同一wa）
//

// assign issue_en1= bypass_inra1[1].valid && bypass_inra2[1].valid&& 
// (~((candidate1.ctl.jump||candidate1.ctl.branch)&&(~candidate2.valid || ~(bypass_inra1[0].valid && bypass_inra2[0].valid))));
// assign have_slot=(candidate1.ctl.branch||candidate1.ctl.jump)&&issue_en[1];
// assign issue_en[0]=bypass_inra1[0].valid && bypass_inra2[0].valid 
// && ~((candidate1.ctl.regwrite&&(candidate1.rdst==candidate2.ra1||candidate1.rdst==candidate2.ra2)&&~have_slot)
//         ||(multi_op(candidate1.ctl.op)&&multi_op(candidate2.ctl.op))
//         ||(candidate1.ctl.cp0write&&candidate2.ctl.cp0write)||~issue_en[1]||candidate2.ctl.branch||candidate2.ctl.jump
//         ||(candidate1.ctl.lowrite&&candidate2.ctl.lotoreg)||(candidate1.ctl.hiwrite&&candidate2.ctl.hitoreg)
//         ||(candidate1.ctl.cp0write&&candidate2.ctl.cp0toreg)||(candidate1.ctl.cp0toreg&&candidate2.ctl.cp0toreg)
//         ||(candidate1.cp0_ctl.ctype==EXCEPTION||candidate1.cp0_ctl.ctype==ERET));
        

// (((que_empty&&~issue_en[1]&&dataD[1].valid)||(que_empty&&~issue_en[0]&&dataD[0].valid)||( ~que_empty&&dataD[1].valid&&~(pop(head)==tail&&issue_en[0]))||(~que_empty&&dataD[0].valid&&pop(head)==tail&&issue_en[0])) && push(tail)==head)
//                 || (((que_empty&&~issue_en[1]&&dataD[1].valid&&dataD[0].valid) || (~que_empty && dataD[0].valid&& ~ (pop(head)==tail&&issue_en[0]))) && push(push(tail))==head) ;

// always_ff @(posedge clk) begin
//     if (reset) begin
//         head<='0;
//         tail<='0;
//         // issue_queue<='0;
//     end else

//     if (flush_que) begin
//         head<=tail;
//     end else begin
//         if (~overflow && ~stallI) begin
//             if (que_empty) begin
//                 if (~issue_en[1]&&dataD[1].valid) begin
//                     // issue_queue[tail]<=dataD[1];
//                     tail<=push(tail);
//                     if (dataD[0].valid) begin
//                         // issue_queue[push(tail)]<=dataD[0];
//                         tail<=push(push(tail));
//                     end
//                 end else if (~issue_en[0]&&dataD[0].valid) begin
//                     // issue_queue[tail]<=dataD[0];
//                     tail<=push(tail);
//                 end
//             end else begin
//                 //不存在有1无0的情况
//                 if (dataD[1].valid&&~(pop(head)==tail&&issue_en[0])) begin
//                         // issue_queue[tail]<=dataD[1];
//                         tail<=push(tail);
//                 end
//                 if (dataD[0].valid) begin
//                     if (pop(head)==tail&&issue_en[0]) begin
//                         // issue_queue[tail]<=dataD[0];
//                         tail<=push(tail);
//                     end else begin
//                         // issue_queue[push(tail)]<=dataD[0];
//                         tail<=push(push(tail));
//                     end
//                 end
//             end
//         end
        
//         if (~stallI || (stallI && overflow && ~stallI_de)) begin
//                 if (~que_empty) begin
//             if (issue_en[1]) begin
//                 head<=pop(head);
//                 if (pop(head)!=tail&&issue_en[0]) begin
//                     head<=pop(pop(head));
//                 end
//             end
//         end
//         end
//     end
// end
// u1 last1;
// assign last1=pop(head)==tail;
// ||issue_en[1]&&~issue_en[0]&&dataD[0].valid


// always_ff @(posedge clk) begin
//     if (reset||flush_que) begin
//         tail<='0;
//     end else begin
//         if(~overflow&&~stallI) begin
//         if ((que_empty&&~issue_en[1]&&dataD[1].valid)
//         ||(~que_empty&&dataD[1].valid&&~(last1&&issue_en[0]))) begin
//             tail<=push(tail);
//             for (int i=0; i<ISSUE_QUEUE_SIZE; ++i) begin
//                 if (i[ISSUE_QUEUE_WIDTH-1:0]==tail) begin
//                     issue_queue[i]<=dataD[1];
//                 end
//             end
//         end else if ((que_empty&&issue_en[1]&&dataD[0].valid&&~issue_en[0])
//         ||(~que_empty&&last1&&issue_en[0])) begin
//             tail<=push(tail);
//             for (int i=0; i<ISSUE_QUEUE_SIZE; ++i) begin
//                 if (i[ISSUE_QUEUE_WIDTH-1:0]==tail) begin
//                     issue_queue[i]<=dataD[0];
//                 end
//             end
//         end
//         if (que_empty&&~issue_en[1]&&dataD[1].valid&&dataD[0].valid
//         ||(~que_empty&&dataD[0].valid&&~(last1&&issue_en[0]))) begin
//             tail<=push(push(tail));
//             for (int i=0; i<ISSUE_QUEUE_SIZE; ++i) begin
//                 if (i[ISSUE_QUEUE_WIDTH-1:0]==push(tail)) begin
//                     issue_queue[i]<=dataD[0];
//                 end
//             end
//         end
//     end
//     end
// end

// always_comb begin

  //   assign  issue_bypass_out[1].cp0ra= candidate1.cp0ra;
//   assign  issue_bypass_out[1].lo_read= candidate1.ctl.op==MFLO;
//   assign  issue_bypass_out[1].hi_read= candidate1.ctl.op==MFHI;
//   assign  issue_bypass_out[1].cp0_read= candidate1.ctl.op==MFC0;
//   assign  issue_bypass_out[0].cp0ra= candidate2.cp0ra;
//   assign  issue_bypass_out[0].lo_read= candidate2.ctl.op==MFLO;
//   assign  issue_bypass_out[0].hi_read= candidate2.ctl.op==MFHI;
//   assign  issue_bypass_out[0].cp0_read= candidate2.ctl.op==MFC0;
    // if (que_empty) begin
    //     for (int i=1; i>=0; --i) begin
    //         if (dataD[i].valid) begin
    //             issue_bypass_out[i].ra1= dataD[i].ra1;
    //             issue_bypass_out[i].ra2= dataD[i].ra2;
    //             issue_bypass_out[i].cp0ra= dataD[i].cp0ra;
    //             issue_bypass_out[i].lo_read= dataD[i].ctl.op==MFLO;
    //             issue_bypass_out[i].hi_read= dataD[i].ctl.op==MFHI;
    //             issue_bypass_out[i].cp0_read= dataD[i].ctl.op==MFC0;
    //         end else begin
    //             issue_bypass_out[i]='0;
    //         end
    //     end
    // end else begin
    //         issue_bypass_out[1].ra1= issue_queue[head].ra1;
    //         issue_bypass_out[1].ra2= issue_queue[head].ra2;
    //         issue_bypass_out[1].cp0ra= issue_queue[head].cp0ra;
    //         issue_bypass_out[1].lo_read= issue_queue[head].ctl.op==MFLO;
    //         issue_bypass_out[1].hi_read= issue_queue[head].ctl.op==MFHI;
    //         issue_bypass_out[1].cp0_read= issue_queue[head].ctl.op==MFC0;
    //         issue_bypass_out[0].ra1= issue_queue[pop(head)].ra1;
    //         issue_bypass_out[0].ra2= issue_queue[pop(head)].ra2;
    //         issue_bypass_out[0].cp0ra= issue_queue[pop(head)].cp0ra;
    //         issue_bypass_out[0].lo_read= issue_queue[pop(head)].ctl.op==MFLO;
    //         issue_bypass_out[0].hi_read= issue_queue[pop(head)].ctl.op==MFHI;
    //         issue_bypass_out[0].cp0_read= issue_queue[pop(head)].ctl.op==MFC0;
    // end
// end

        // if (que_empty) begin
        //     dataI[1]='0;
        //     dataI[0]='0;
            // for (int i=0; i<2; ++i) begin
            //     if (issue_en[i]) begin
            //     dataI[i].ctl=dataD[i].ctl;
            //     dataI[i].pc=dataD[i].pc;
            //     dataI[i].valid=dataD[i].valid;
            //     dataI[i].imm=dataD[i].imm;
            //     // dataI[i].is_slot=dataD[i].is_slot;
            //     dataI[i].rd1= bypass_inra1[i].bypass? bypass_inra1[i].data :rd1[i];
            //     dataI[i].rd2= bypass_inra2[i].bypass? bypass_inra2[i].data :rd2[i];
            //     dataI[i].raw_instr=dataD[i].raw_instr;
            //     dataI[i].cp0ra=dataD[i].cp0ra;
            //     dataI[i].raw_instr=dataD[i].raw_instr;
            //     dataI[i].rdst=dataD[i].rdst;
            //     dataI[i].cp0_ctl=dataD[i].cp0_ctl;
            //     end
            // end

    

endmodule

`endif