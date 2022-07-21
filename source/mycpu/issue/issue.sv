`ifndef ISSUE_SV
`define ISSUE_SV

`ifdef VERILATOR
`include "common.svh"
`include "pipes.svh"
`endif 

module issue(
    input clk,
    input decode_data_t dataD [1:0],
    output issue_data_t dataI [1:0],
    // input word_t rd1[1:0],rd2[1:0],
    output bypass_issue_t issue_bypass_out[1:0],
    input bypass_output_t bypass_in[1:0],
    input u1 flush_que
);
localparam ISSUE_QUEUE_WIDTH = $clog2(ISSUE_QUEUE_SIZE);
localparam ISSUE_QUEUE_SIZE = 16;
localparam type index_t = logic [ISSUE_QUEUE_WIDTH-1:0];
decode_data_t candidate[1:0];

function index_t push(index_t tail);
    return tail==0? 4'hf:tail-1;
endfunction
function index_t pop(index_t head);
    return head==0? 4'hf:head-1;
endfunction
function u1 multi_op(decoded_op_t op);
    return op==DIV||op==DIVU||op==MULT||op==MULTU;
endfunction
u1 que_empty;
assign que_empty=head==tail;

decode_data_t issue_queue [ISSUE_QUEUE_SIZE-1:0];
index_t head;
index_t tail;

u1 issue_en[1:0];
assign issue_en[1]=bypass_in[1].valid;

always_comb begin
    issue_en[0]=bypass_in[0].valid;
    if ((dataD[1].ctl.regwrite&&(dataD[1].rdst==dataD[0].ra1||dataD[1].rdst==dataD[0].ra2))
        ||(multi_op(dataD[1].ctl.op)&&multi_op(dataD[0].ctl.op))
        ||(dataD[1].ctl.cp0write&&dataD[0].ctl.cp0write)||~issue_en[1]||
        (dataD[1].ctl.hiwrite&&dataD[0].ctl.hiwrite)||
        (dataD[1].ctl.lowrite&&dataD[0].ctl.lowrite)) begin
        issue_en[0]='0;
    end
end

always_ff @(posedge clk) begin
    if (flush_que) begin
        head <= tail;
    end

    if (que_empty) begin
        if (~issue_en[1]&&dataD[1].valid) begin
            issue_queue[tail]<=dataD[1];
            tail<=push(tail);
            if (dataD[0].valid) begin
                issue_queue[tail]<=dataD[0];
                tail<=push(tail);
            end
        end else if (~issue_en[0]&&dataD[1].valid) begin
            issue_queue[tail]<=dataD[0];
            tail<=push(tail);
        end
    end else begin
        //不存在有1无0的情况
        for (int i=1; i>=0; --i) begin
            if (dataD[i].valid) begin
                issue_queue[tail]<=dataD[i];
                tail<=push(tail);
            end
        end
    end

    if (~que_empty) begin
        unique case ({issue_en[1],issue_en[0]})
            2'b10:head<=pop(head);
            2'b11:head<=pop(pop(head));
            default: ;
        endcase
    end
    
end

// for (genvar i=1; i>=0; --i) begin

always_comb begin
    if (que_empty) begin
        for (int i=1; i>=0; --i) begin
            if (dataD[i].valid) begin
                issue_bypass_out[i].ra1= dataD[i].ra1;
                issue_bypass_out[i].ra2= dataD[i].ra2;
                issue_bypass_out[i].cp0ra= dataD[i].cp0ra;
                issue_bypass_out[i].lo_read= dataD[i].ctl.op==MFLO;
                issue_bypass_out[i].hi_read= dataD[i].ctl.op==MFHI;
                issue_bypass_out[i].cp0_read= dataD[i].ctl.op==MFC0;
            end else begin
                issue_bypass_out[i]='0;
            end
        end
    end else begin
            issue_bypass_out[1].ra1= issue_queue[head].ra1;
            issue_bypass_out[1].ra2= issue_queue[head].ra2;
            issue_bypass_out[1].cp0ra= issue_queue[head].cp0ra;
            issue_bypass_out[1].lo_read= issue_queue[head].ctl.op==MFLO;
            issue_bypass_out[1].hi_read= issue_queue[head].ctl.op==MFHI;
            issue_bypass_out[1].cp0_read= issue_queue[head].ctl.op==MFC0;
            issue_bypass_out[0].ra1= issue_queue[pop(head)].ra1;
            issue_bypass_out[0].ra2= issue_queue[pop(head)].ra2;
            issue_bypass_out[0].cp0ra= issue_queue[pop(head)].cp0ra;
            issue_bypass_out[0].lo_read= issue_queue[pop(head)].ctl.op==MFLO;
            issue_bypass_out[0].hi_read= issue_queue[pop(head)].ctl.op==MFHI;
            issue_bypass_out[0].cp0_read= issue_queue[pop(head)].ctl.op==MFC0;
    end
end

    always_comb begin
        dataI='0; 
        if (que_empty) begin
            if (issue_en[1]) begin
                dataI[1].ctl=dataD[1].ctl;
                dataI[1].pc=dataD[1].pc;
                dataI[1].valid=dataD[1].valid;
                dataI[1].imm=dataD[1].imm;
                dataI[1].is_slot=dataD[1].is_slot;
                dataI[1].rd1= bypass_in[1].bypass[1]? bypass_in[1].data :dataD[1].rd1;
                dataI[1].rd2= bypass_in[1].bypass[0]? bypass_in[1].data :dataD[1].rd2;
                dataI[1].raw_instr=dataD[1].raw_instr;
                dataI[1].cp0ra=dataD[1].cp0ra;
                dataI[1].raw_instr=dataD[1].raw_instr;
                dataI[1].rdst=dataD[1].rdst;
                if (issue_en[0]) begin
                    dataI[0].ctl=dataD[0].ctl;
                    dataI[0].pc=dataD[0].pc;
                    dataI[0].valid=dataD[0].valid;
                    dataI[0].imm=dataD[0].imm;
                    dataI[0].is_slot=dataD[0].is_slot;
                    dataI[0].rd1=bypass_in[0].bypass[1]? bypass_in[0].data :dataD[0].rd1;
                    dataI[0].rd2=bypass_in[0].bypass[0]? bypass_in[0].data :dataD[0].rd2;
                    dataI[0].raw_instr=dataD[0].raw_instr;
                    dataI[0].cp0ra=dataD[0].cp0ra;
                    dataI[0].raw_instr=dataD[0].raw_instr;
                    dataI[0].rdst=dataD[1].rdst;
                end 
            end
        end else begin
            if (issue_en[1]) begin
                dataI[1].ctl=issue_queue[head].ctl;
                dataI[1].pc=issue_queue[head].pc;
                dataI[1].valid=issue_queue[head].valid;
                dataI[1].imm=issue_queue[head].imm;
                dataI[1].is_slot=issue_queue[head].is_slot;
                dataI[1].rd1=bypass_in[1].bypass[1]? bypass_in[1].data :issue_queue[head].rd1;
                dataI[1].rd2=bypass_in[1].bypass[0]? bypass_in[1].data :issue_queue[head].rd2;
                dataI[1].raw_instr=issue_queue[head].raw_instr;
                dataI[1].cp0ra=issue_queue[head].cp0ra;
                dataI[1].raw_instr=issue_queue[head].raw_instr;
                dataI[1].rdst=issue_queue[head].rdst;
                if (issue_en[0]) begin
                    dataI[0].ctl=issue_queue[pop(head)].ctl;
                    dataI[0].pc=issue_queue[pop(head)].pc;
                    dataI[0].valid=issue_queue[pop(head)].valid;
                    dataI[0].imm=issue_queue[pop(head)].imm;
                    dataI[0].is_slot=issue_queue[pop(head)].is_slot;
                    dataI[0].rd1=bypass_in[0].bypass[1]? bypass_in[0].data :issue_queue[pop(head)].rd1;
                    dataI[0].rd2=bypass_in[0].bypass[0]? bypass_in[0].data :issue_queue[pop(head)].rd2;
                    dataI[0].raw_instr=issue_queue[pop(head)].raw_instr;
                    dataI[0].cp0ra=issue_queue[pop(head)].cp0ra;
                    dataI[0].raw_instr=issue_queue[pop(head)].raw_instr;
                    dataI[0].rdst=issue_queue[pop(head)].rdst;
                end
            end
        end
        
end

endmodule

`endif