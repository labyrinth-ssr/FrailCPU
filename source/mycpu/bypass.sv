`ifndef BYPASS_SV
`define BYPASS_SV

`ifdef VERILATOR
`include "common.svh"
`include "pipes.svh"
`endif 

module bypass(
    input bypass_input_t dataE_in[1:0],
    input bypass_input_t dataM1_in[1:0],
    input bypass_input_t dataM2_in[1:0],
    // input creg_addr_t dataEnxt_in[1:.dst0],
    input bypass_issue_t dataI_in[1:0],
    input bypass_execute_t dataEnxt_in[1:0],
    // input hi,hi,
    // input u8 cp0ra,
    output bypass_output_t out [1:0]
);
    // u1 no_relate_[1:0][1:0];
    // u1 invalid[1:0];

    for (genvar i=0; i<2; ++i) begin//针对issue head的对应端口
        always_comb begin
                out[i]='0;
                if ((dataEnxt_in[0].rdst==dataI_in[i].ra1||dataEnxt_in[0].rdst==dataI_in[i].ra2)&&dataEnxt_in[0].regwrite) begin
                    out[i].valid='0;//e阶段有来不及转发的写入
                end else if ((dataEnxt_in[1].rdst==dataI_in[i].ra1||dataEnxt_in[1].rdst==dataI_in[i].ra2)&&dataEnxt_in[1].regwrite) begin
                    out[i].valid='0;
                end else if ((dataE_in[0].rdst==dataI_in[i].ra1||dataE_in[0].rdst==dataI_in[i].ra2)&&dataE_in[0].regwrite) begin
                    out[i].valid=dataE_in[0].memtoreg=='0;
                    out[i].bypass[1]=dataE_in[0].memtoreg=='0&&dataE_in[0].rdst==dataI_in[i].ra1;
                    out[i].bypass[0]=dataE_in[0].memtoreg=='0&&dataE_in[0].rdst==dataI_in[i].ra2;
                    out[i].data=dataE_in[0].data;
                end else if ((dataE_in[1].rdst==dataI_in[i].ra1||dataE_in[1].rdst==dataI_in[i].ra2)&&dataE_in[1].regwrite) begin
                    out[i].valid=dataE_in[1].memtoreg=='0;
                    out[i].bypass[1]=dataE_in[1].memtoreg=='0&&dataE_in[1].rdst==dataI_in[i].ra1;
                    out[i].bypass[0]=dataE_in[1].memtoreg=='0&&dataE_in[1].rdst==dataI_in[i].ra2;
                    out[i].data=dataE_in[1].data;
                end else if (dataM1_in[0].regwrite&&(dataM1_in[0].rdst==dataI_in[i].ra1||dataM1_in[0].rdst==dataI_in[i].ra2)) begin
                    out[i].valid=dataM1_in[0].memtoreg=='0;
                    out[i].bypass[1]=dataM1_in[0].memtoreg=='0&&dataM1_in[0].rdst==dataI_in[i].ra1;
                    out[i].bypass[0]=dataM1_in[0].memtoreg=='0&&dataM1_in[0].rdst==dataI_in[i].ra2;
                    out[i].data=dataM1_in[0].data;
                end else if (dataM1_in[1].regwrite&&(dataM1_in[1].rdst==dataI_in[i].ra1||dataM1_in[1].rdst==dataI_in[i].ra2)) begin
                    out[i].valid=dataM1_in[1].memtoreg=='0;
                    out[i].bypass[1]=dataM1_in[1].memtoreg=='0&&dataM1_in[1].rdst==dataI_in[i].ra1;
                    out[i].bypass[0]=dataM1_in[1].memtoreg=='0&&dataM1_in[1].rdst==dataI_in[i].ra2;
                    out[i].data=dataM1_in[1].data;
                end else if (dataM2_in[0].regwrite&&(dataM2_in[0].rdst==dataI_in[i].ra1||dataM2_in[0].rdst==dataI_in[i].ra2)) begin
                    out[i].valid='1;
                    out[i].bypass[1]=dataM2_in[0].rdst==dataI_in[i].ra1;
                    out[i].bypass[0]=dataM2_in[0].rdst==dataI_in[i].ra2;
                    out[i].data=dataM2_in[0].data;
                end else if (dataM2_in[1].regwrite&&(dataM2_in[1].rdst==dataI_in[i].ra1||dataM2_in[1].rdst==dataI_in[i].ra2)) begin
                    out[i].valid='1;
                    out[i].bypass[1]=dataM2_in[1].rdst==dataI_in[i].ra1;
                    out[i].bypass[0]=dataM2_in[1].rdst==dataI_in[i].ra2;
                    out[i].data=dataM2_in[1].data;
                end 

                // else if (dataI_in[i].lo_read) begin
                //     if (dataEnxt_in[0].lowrite) begin
                //     out[i].valid='0;//e阶段有来不及转发的写入
                // end else if (dataEnxt_in[1].lowrite) begin
                //     out[i].valid='0;
                // end else if (dataE_in[0].lowrite) begin
                //     out[i].valid='1;
                //     out[i].data=dataE_in[0].data;
                // end else if (dataE_in[1].lowrite) begin
                //     out[i].valid='1;
                //     out[i].data=dataE_in[1].data;
                // end else if (dataM1_in[0].lowrite) begin
                //     out[i].valid='1;
                //     out[i].data=dataM1_in[0].data;
                // end else if (dataM1_in[1].lowrite) begin
                //     out[i].valid='1;
                //     out[i].data=dataM1_in[1].data;
                // end else if (dataM2_in[0].lowrite) begin
                //     out[i].valid='1;
                //     out[i].data=dataM2_in[0].data;
                // end else if (dataM2_in[1].lowrite) begin
                //     out[i].valid='1;
                //     out[i].data=dataM2_in[1].data;
                // end
                // end

                // else if (dataI_in[i].hi_read) begin
                //     if (dataEnxt_in[0].hiwrite) begin
                //     out[i].valid='0;//e阶段有来不及转发的写入
                // end else if (dataEnxt_in[1].hiwrite) begin
                //     out[i].valid='0;
                // end else if (dataE_in[0].hiwrite) begin
                //     out[i].valid='1;
                //     out[i].data=dataE_in[0].data;
                // end else if (dataE_in[1].hiwrite) begin
                //     out[i].valid='1;
                //     out[i].data=dataE_in[1].data;
                // end else if (dataM1_in[0].hiwrite) begin
                //     out[i].valid='1;
                //     out[i].data=dataM1_in[0].data;
                // end else if (dataM1_in[1].hiwrite) begin
                //     out[i].valid='1;
                //     out[i].data=dataM1_in[1].data;
                // end else if (dataM2_in[0].hiwrite) begin
                //     out[i].valid='1;
                //     out[i].data=dataM2_in[0].data;
                // end else if (dataM2_in[1].hiwrite) begin
                //     out[i].valid='1;
                //     out[i].data=dataM2_in[1].data;
                // end
                // end

                // else if (dataI_in[i].cp0_read) begin
                //     if (dataEnxt_in[0].cp0write&&dataEnxt_in[0].cp0ra==dataI_in[i].cp0ra) begin
                //         out[i].valid='0;
                //     end else if (dataEnxt_in[1].cp0write&&dataEnxt_in[1].cp0ra==dataI_in[i].cp0ra) begin
                //         out[i].valid='0;
                //     end else if (dataE_in[0].cp0write&&dataE_in[0].cp0ra==dataI_in[i].cp0ra) begin
                //         out[i].valid='1;
                //         out[i].data=dataE_in[0].data;
                //     end else if (dataE_in[1].cp0write&&dataE_in[1].cp0ra==dataI_in[i].cp0ra) begin
                //         out[i].valid='1;
                //         out[i].data=dataE_in[1].data;
                //     end else if (dataM1_in[0].cp0write&&dataM1_in[0].cp0ra==dataI_in[i].cp0ra) begin
                //         out[i].valid='1;
                //         out[i].data=dataM1_in[0].data;
                //     end else if (dataM1_in[1].cp0write&&dataM1_in[1].cp0ra==dataI_in[i].cp0ra) begin
                //         out[i].valid='1;
                //         out[i].data=dataM1_in[1].data;
                //     end else if (dataM2_in[0].cp0write&&dataM2_in[0].cp0ra==dataI_in[i].cp0ra) begin
                //         out[i].valid='1;
                //         out[i].data=dataM2_in[0].data;
                //     end else if (dataM2_in[1].cp0write&&dataM2_in[1].cp0ra==dataI_in[i].cp0ra) begin
                //         out[i].valid='1;
                //         out[i].data=dataM2_in[1].data;
                //     end
                // end

                else begin
                    out[i].valid='1;
                    out[i].data='0;
                end
                
        end
    end
    
endmodule


`endif 