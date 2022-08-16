`ifndef BYPASSM_SV
`define BYPASSM_SV

`ifdef VERILATOR
`include "common.svh"
`include "pipes.svh"
`endif 

module bypassM(
    // input cp0_bypass_input_t [1:0] dataE_in,
    input cp0_bypass_input_t [1:0] dataM1_in,
    input cp0_bypass_input_t [1:0] dataM2_in,
    input cp0_bypass_input_t [1:0] dataM3_in,
    // input creg_addr_t [1:0] dataEnxt_in[1:.dst0],
    input u8 cp0ra,
    // input hi,hi,
    // input u8 cp0ra,
    output bypass_output_t outcp0r
    // output bypass_output_t [1:0] outra2 

);
    // u1 no_relate_[1:0][1:0];
    // u1 invalid[1:0];
// function u1 delay_toreg(bypass_input_t a);
//     return a.memtoreg||a.lotoreg||a.hitoreg||a.cp0toreg;
// endfunction

        always_comb begin
                outcp0r.data='0;
                outcp0r.bypass='0;
                outcp0r.valid='1;
            if (dataM1_in[0].cp0write&&(dataM1_in[0].cp0wa==cp0ra)) begin
                outcp0r.bypass='1;
                outcp0r.data=dataM1_in[0].data;
            end else if (dataM1_in[1].cp0write&&(dataM1_in[1].cp0wa==cp0ra)) begin
                outcp0r.bypass='1;
                outcp0r.data=dataM1_in[1].data;
            end else if (dataM2_in[0].cp0write&&(dataM2_in[0].cp0wa==cp0ra)) begin
                outcp0r.bypass='1;
                outcp0r.data=dataM2_in[0].data;
            end else if (dataM2_in[1].cp0write&&(dataM2_in[1].cp0wa==cp0ra)) begin
                outcp0r.bypass='1;
                outcp0r.data=dataM2_in[1].data;
            end else if (dataM3_in[0].cp0write&&(dataM3_in[0].cp0wa==cp0ra)) begin
                outcp0r.bypass='1;
                outcp0r.data=dataM3_in[0].data;
            end else if (dataM3_in[1].cp0write&&(dataM3_in[1].cp0wa==cp0ra)) begin
                outcp0r.bypass='1;
                outcp0r.data=dataM3_in[1].data;
            end 
            else begin
            end
        end
    
endmodule
`endif 
