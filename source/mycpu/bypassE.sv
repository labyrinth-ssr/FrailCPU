`ifndef BYPASSE_SV
`define BYPASSE_SV

`ifdef VERILATOR
`include "common.svh"
`include "pipes.svh"
`endif 

module bypassE(
    input bypass_input_t [1:0] dataE_in,
    input bypass_input_t [1:0] dataM1_in,
    input bypass_input_t [1:0] dataM2_in,
    input bypass_input_t [1:0] dataM3_in,
    // input creg_addr_t [1:0] dataEnxt_in[1:.dst0],
    input bypass_issue_t [1:0] dataE_nxt_in,
    // input hi,hi,
    // input u8 cp0ra,
    output bypass_output_t [1:0] outra1,
    output bypass_output_t [1:0] outra2 

);
    // u1 no_relate_[1:0][1:0];
    // u1 invalid[1:0];
function u1 delay_toreg(bypass_input_t a);
    return a.memtoreg||a.lotoreg||a.hitoreg||a.cp0toreg||a.mul;
endfunction

    for (genvar i=0; i<2; ++i) begin//针对issue head的对应端口
        always_comb begin
                outra1[i].data='0;
                outra1[i].bypass='0;
                outra1[i].valid='1;
            if ((dataE_in[0].rdst==dataE_nxt_in[i].ra1)&&dataE_in[0].regwrite) begin
                // //outra1[i].valid=~delay_toreg(dataE_in[0]);
                outra1[i].bypass=~delay_toreg(dataE_in[0]);
                outra1[i].data=dataE_in[0].data;
            end else if ((dataE_in[1].rdst==dataE_nxt_in[i].ra1)&&dataE_in[1].regwrite) begin
                // outra1[i].valid='1
                outra1[i].bypass=~delay_toreg(dataE_in[1]);
                outra1[i].data=dataE_in[1].data;
            end else if (dataM1_in[0].regwrite&&(dataM1_in[0].rdst==dataE_nxt_in[i].ra1)) begin
                // outra1[i].valid=~delay_toreg(dataM1_in[0]);
                outra1[i].bypass=~delay_toreg(dataM1_in[0]);
                outra1[i].data=dataM1_in[0].data;
            end else if (dataM1_in[1].regwrite&&(dataM1_in[1].rdst==dataE_nxt_in[i].ra1)) begin
                // outra1[i].valid=~delay_toreg(dataM1_in[1]);
                outra1[i].bypass=~delay_toreg(dataM1_in[1]);
                outra1[i].data=dataM1_in[1].data;
            end else if (dataM2_in[0].regwrite&&(dataM2_in[0].rdst==dataE_nxt_in[i].ra1)) begin
                // outra1[i].valid='1;
                outra1[i].bypass=~delay_toreg(dataM2_in[0]);
                outra1[i].data=dataM2_in[0].data;
            end else if (dataM2_in[1].regwrite&&(dataM2_in[1].rdst==dataE_nxt_in[i].ra1)) begin
                // outra1[i].valid='1;
                outra1[i].bypass=~delay_toreg(dataM2_in[1]);
                outra1[i].data=dataM2_in[1].data;
            end else if (dataM3_in[0].regwrite&&(dataM3_in[0].rdst==dataE_nxt_in[i].ra1)) begin
                //outra1[i].valid='1;
                outra1[i].bypass=delay_toreg(dataM3_in[0]);
                outra1[i].data=dataM3_in[0].data;
            end else if (dataM3_in[1].regwrite&&(dataM3_in[1].rdst==dataE_nxt_in[i].ra1)) begin
                //outra1[i].valid='1;
                outra1[i].bypass=delay_toreg(dataM3_in[1]);
                outra1[i].data=dataM3_in[1].data;
            end 
            else begin
            end
        end
    end

for (genvar i=0; i<2; ++i) begin//针对issue head的对应端口
        always_comb begin
                    outra2[i].data='0;
                    outra2[i].bypass='0;
                    outra2[i].valid='1;
                if ((dataE_in[0].rdst==dataE_nxt_in[i].ra2)&&dataE_in[0].regwrite) begin
                    // //outra2[i].valid=~delay_toreg(dataE_in[0]);
                    outra2[i].bypass=~delay_toreg(dataE_in[0]);
                    outra2[i].data=dataE_in[0].data;
                end else if ((dataE_in[1].rdst==dataE_nxt_in[i].ra2)&&dataE_in[1].regwrite) begin
                    // outra2[i].valid='1
                    outra2[i].bypass=~delay_toreg(dataE_in[1]);
                    outra2[i].data=dataE_in[1].data;
                end else if (dataM1_in[0].regwrite&&(dataM1_in[0].rdst==dataE_nxt_in[i].ra2)) begin
                    // outra2[i].valid=~delay_toreg(dataM1_in[0]);
                    outra2[i].bypass=~delay_toreg(dataM1_in[0]);
                    outra2[i].data=dataM1_in[0].data;
                end else if (dataM1_in[1].regwrite&&(dataM1_in[1].rdst==dataE_nxt_in[i].ra2)) begin
                    // outra2[i].valid=~delay_toreg(dataM1_in[1]);
                    outra2[i].bypass=~delay_toreg(dataM1_in[1]);
                    outra2[i].data=dataM1_in[1].data;
                end else if (dataM2_in[0].regwrite&&(dataM2_in[0].rdst==dataE_nxt_in[i].ra2)) begin
                    // outra2[i].valid='1;
                    outra2[i].bypass=~delay_toreg(dataM2_in[0]);
                    outra2[i].data=dataM2_in[0].data;
                end else if (dataM2_in[1].regwrite&&(dataM2_in[1].rdst==dataE_nxt_in[i].ra2)) begin
                    // outra2[i].valid='1;
                    outra2[i].bypass=~delay_toreg(dataM2_in[1]);
                    outra2[i].data=dataM2_in[1].data;
                end else if (dataM3_in[0].regwrite&&(dataM3_in[0].rdst==dataE_nxt_in[i].ra2)) begin
                    //outra2[i].valid='1;
                    outra2[i].bypass=delay_toreg(dataM3_in[0]);
                    outra2[i].data=dataM3_in[0].data;
                end else if (dataM3_in[1].regwrite&&(dataM3_in[1].rdst==dataE_nxt_in[i].ra2)) begin
                    //outra2[i].valid='1;
                    outra2[i].bypass=delay_toreg(dataM3_in[1]);
                    outra2[i].data=dataM3_in[1].data;
                end 
                else begin
                end
        end
    end
    
endmodule
`endif 
