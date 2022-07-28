`include "pipes.svh"
`include "common.svh"
`include "decode.svh"



module decoder (
        input word_t instr,
        input u1 valid,
        // input creg_addr_t rs, rt, rd,
        // output decoded_op_t ctl.op,
        input cp0_control_t cp0_ctl_old,
        output control_t ctl,
        output creg_addr_t srcrega, srcregb, destreg,
        output cp0_control_t cp0_ctl,
        output u1 jump
    );
    u6 op_;
    creg_addr_t rs,rd,rt;
    assign op_ = instr[31:26];
    assign rt=instr[20:16];
    assign rs=instr[25:21];
    assign rd=instr[15:11];
    u6 func;
    assign func = instr[5:0];
    u1 exception_ri;

    always_comb begin
        exception_ri = 1'b0;
        ctl = '0;
        cp0_ctl=cp0_ctl_old;
        jump='0;
        if (valid) begin
            case (op_)
            `OP_MUL: begin
                ctl.op = MULT;
                ctl.regwrite = 1'b1;
                ctl.alusrc = REGB;
                ctl.mul_div_r = 1'b1;
                srcrega = rs;
                srcregb = rt;
                destreg = rd;
            end
            `OP_ADDI: begin
                ctl.op = ADD;
                ctl.alufunc = ALU_ADD;
                ctl.regwrite = 1'b1;
                ctl.alusrc = IMM;
                srcrega = rs;
                srcregb = '0;
                destreg = rt;
            end  
            `OP_ADDIU: begin
                ctl.op = ADDU;
                ctl.alufunc = ALU_ADDU;
                ctl.regwrite = 1'b1;
                ctl.alusrc = IMM;
                srcrega = rs;
                srcregb = '0;
                destreg = rt;
            end 
            `OP_SLTI:  begin
                ctl.op = SLT;
                ctl.alufunc = ALU_SLT;
                ctl.regwrite = 1'b1;
                
                ctl.alusrc = IMM;
                srcrega = rs;
                srcregb = '0;
                destreg = rt;
            end 
            `OP_SLTIU: begin
                ctl.op = SLTU;
                ctl.alufunc = ALU_SLTU;
                ctl.regwrite = 1'b1;
                ctl.alusrc = IMM;
                srcrega = rs;
                srcregb = '0;
                destreg = rt;
            end 
            `OP_ANDI: begin
                ctl.op = AND;
                ctl.alufunc = ALU_AND;
                ctl.regwrite = 1'b1;
                ctl.zeroext = 1'b1;
                ctl.alusrc = IMM;
                srcrega = rs;
                srcregb = '0;
                destreg = rt;
            end  
            `OP_LUI:  begin
                ctl.op = LUI;
                ctl.alufunc = ALU_LUI;
                ctl.regwrite = 1'b1;
                ctl.alusrc = IMM;
                srcrega = '0;
                srcregb = '0;
                destreg = rt;
            end  
            `OP_ORI:  begin
                ctl.op = OR;
                ctl.alufunc = ALU_OR;
                ctl.regwrite = 1'b1;
                ctl.alusrc = IMM;
                ctl.zeroext = 1'b1;
                srcrega = rs;
                srcregb = '0;
                destreg = rt;
            end  
            `OP_XORI: begin
                ctl.op = XOR;
                ctl.alufunc = ALU_XOR;
                ctl.regwrite = 1'b1;
                ctl.alusrc = IMM;
                ctl.zeroext = 1'b1;
                srcrega = rs;
                srcregb = '0;
                destreg = rt;
            end  
            `OP_BEQ: begin
                ctl.op = BEQ;
                ctl.branch = 1'b1;
                jump='1;
                ctl.branch_type = T_BEQ;
                srcrega = rs;
                srcregb = rt;
                destreg = '0;
            end   
            `OP_BNE: begin
                ctl.op = BNE;
                jump='1;
                ctl.branch = 1'b1;
                ctl.branch_type = T_BNE;
                srcrega = rs;
                srcregb = rt;
                destreg = '0;
            end   
            `OP_BGEZ: begin
                case (instr[20:16])
                    `B_BGEZ:  begin
                        ctl.op = BGEZ;
                jump='1;
                        ctl.branch = 1'b1;
                        ctl.branch_type = T_BGEZ;
                        srcrega = rs;
                        srcregb = '0;
                        destreg = '0;
                    end  
                    `B_BLTZ: begin
                        ctl.op = BLTZ;
                jump='1;
                        ctl.branch = 1'b1;
                        ctl.branch_type = T_BLTZ;
                        srcrega = rs;
                        srcregb = '0;
                        destreg = '0;
                    end   
                    `B_BGEZAL: begin
                        ctl.op = BGEZAL;
                jump='1;
                        ctl.branch = 1'b1;
                        ctl.regwrite = 1'b1;
                        ctl.branch_type = T_BGEZ;
                        ctl.is_link = 'b1;
                        srcrega = rs;
                        srcregb = '0;
                        destreg = 5'b11111;
                    end 
                    `B_BLTZAL: begin
                        ctl.op = BLTZAL;
                jump='1;
                        ctl.branch = 1'b1;
                        ctl.regwrite = 1'b1;
                        ctl.branch_type = T_BLTZ;
                        ctl.is_link = 'b1;
                        srcrega = rs;
                        srcregb = '0;
                        destreg = 5'b11111;
                    end 
                    default: begin
                        exception_ri = 1'b1;
                        ctl.op = RESERVED;
                        srcrega = '0;
                        srcregb = '0;
                        destreg = '0;
                cp0_ctl.ctype=EXCEPTION;
                    end
                endcase
            end
            `OP_BGTZ: begin
                ctl.op = BGTZ;
                jump='1;
                ctl.branch = 1'b1;
                ctl.branch_type = T_BGTZ;
                srcrega = rs;
                srcregb = '0;
                destreg = '0;
            end  
            `OP_BLEZ: begin
                ctl.op = BLEZ;
                jump='1;
                ctl.branch = 1'b1;
                ctl.branch_type = T_BLEZ;
                srcrega = rs;
                srcregb = '0;
                destreg = '0;
            end              
            `OP_J: begin
                ctl.op = J;
                ctl.jump = 1'b1;
                jump='1;
                srcrega = '0;
                srcregb = '0;
                destreg = '0;
            end     
            `OP_JAL: begin
                ctl.op = JAL;
                jump='1;
                ctl.jump = 1'b1;
                ctl.regwrite = 1'b1;
                ctl.is_link = 'b1;
                srcrega = '0;
                srcregb = '0;
                destreg = 5'b11111;
            end   
            `OP_LB: begin
                ctl.op = LB;
                ctl.regwrite = 1'b1;
                ctl.memtoreg = 1'b1;
                ctl.alusrc = IMM;
                srcrega = rs;
                srcregb = '0;
                destreg = rt;
                ctl.msize=MSIZE1;
                ctl.memsext='1;

            end    
            `OP_LBU: begin
                ctl.op = LBU;
                ctl.regwrite = 1'b1;
                ctl.memtoreg = 1'b1;
                ctl.alusrc = IMM;
                srcrega = rs;
                srcregb = '0;
                destreg = rt;
                ctl.msize=MSIZE1;
            end   
            `OP_LH: begin
                ctl.op = LH;
                ctl.regwrite = 1'b1;
                ctl.memtoreg = 1'b1;
                ctl.alusrc = IMM;
                srcrega = rs;
                srcregb = '0;
                destreg = rt;
                ctl.msize=MSIZE2;
                ctl.memsext='1;
            end    
            `OP_LHU: begin
                ctl.op = LHU;
                ctl.regwrite = 1'b1;
                ctl.memtoreg = 1'b1;
                ctl.alusrc = IMM;
                srcrega = rs;
                srcregb = '0;
                destreg = rt;
                ctl.msize=MSIZE2;
            end   
            `OP_LW: begin
                ctl.op = LW;
                ctl.regwrite = 1'b1;
                ctl.memtoreg = 1'b1;
                ctl.alusrc = IMM;
                srcrega = rs;
                srcregb = '0;
                destreg = rt;
                ctl.msize=MSIZE4;
            end    
            `OP_SB: begin
                ctl.op = SB;
                ctl.memwrite = 1'b1;
                ctl.alusrc = IMM;
                srcrega = rs;
                srcregb = rt;
                destreg = '0;
                ctl.msize=MSIZE1;
            end    
            `OP_SH: begin
                ctl.op = SH;
                ctl.memwrite = 1'b1;
                ctl.alusrc = IMM;
                srcrega = rs;
                srcregb = rt;
                destreg = '0;
                ctl.msize=MSIZE2;

            end    
            `OP_SW: begin
                ctl.op = SW;
                ctl.memwrite = 1'b1;
                ctl.alusrc = IMM;
                srcrega = rs;
                srcregb = rt;
                destreg = '0;
                ctl.msize=MSIZE4;

            end    
            `OP_ERET: begin
                case (instr[25:21])
                    `C_ERET:begin
                        cp0_ctl.ctype=ERET;
                        // cp0_ctl.valid='1;
                        ctl.is_eret = 1'b1;
                        srcrega = '0;
                        srcregb = '0;
                        destreg = '0;        
                    end 
                    `C_MFC0:begin
                        ctl.op = MFC0;
                        cp0_ctl.ctype=INSTR;
                        // cp0_ctl.valid='1;
                        ctl.alufunc = ALU_PASSA;
                        ctl.regwrite = 1'b1;
                        ctl.cp0toreg = 1'b1;
                        srcrega = '0;
                        srcregb = '0;
                        destreg = rt;
                    end 
                    `C_MTC0:begin
                        ctl.op = MTC0;
                        cp0_ctl.ctype=INSTR;
                        cp0_ctl.valid='1;
                        ctl.cp0write = 1'b1;
                        ctl.alufunc = ALU_PASSB;
                        srcrega = '0;
                        srcregb = rt;
                        destreg = '0;
                    end 
                    default: begin
                        exception_ri = 1'b1;
                        ctl.op = RESERVED;
                        srcrega = '0;
                        srcregb = '0;
                        destreg = '0;
                cp0_ctl.ctype=EXCEPTION;
                    end
                endcase
            end
            `OP_RT: begin
                case (func)
                    `F_ADD: begin
                        ctl.op = ADD;
                        ctl.alufunc = ALU_ADD;
                        ctl.regwrite = 1'b1;
                        ctl.alusrc = REGB;
                        srcrega = rs;
                        srcregb = rt;
                        destreg = rd;
                    end    
                    `F_ADDU: begin
                        ctl.op = ADDU;
                        ctl.alufunc = ALU_ADDU;
                        ctl.regwrite = 1'b1;
                        ctl.alusrc = REGB;
                        srcrega = rs;
                        srcregb = rt;
                        destreg = rd;
                    end   
                    `F_SUB: begin
                        ctl.op = SUB;
                        ctl.alufunc = ALU_SUB;
                        ctl.regwrite = 1'b1;
                        ctl.alusrc = REGB;
                        srcrega = rs;
                        srcregb = rt;
                        destreg = rd;
                    end    
                    `F_SUBU: begin
                        ctl.op = SUBU;
                        ctl.alufunc = ALU_SUBU;
                        ctl.regwrite = 1'b1;
                        ctl.alusrc = REGB;
                        srcrega = rs;
                        srcregb = rt;
                        destreg = rd;
                    end   
                    `F_SLT: begin
                        ctl.op = SLT;
                        ctl.alufunc = ALU_SLT;
                        ctl.regwrite = 1'b1;
                        ctl.alusrc = REGB;
                        srcrega = rs;
                        srcregb = rt;
                        destreg = rd;
                    end    
                    `F_SLTU: begin
                        ctl.op = SLTU;
                        ctl.alufunc = ALU_SLTU;
                        ctl.regwrite = 1'b1;
                        ctl.alusrc = REGB;
                        srcrega = rs;
                        srcregb = rt;
                        destreg = rd;
                    end   
                    `F_DIV: begin
                        ctl.op = DIV;
                        ctl.hiwrite = 1'b1;
                        ctl.lowrite = 1'b1;
                        ctl.alusrc = REGB;
                        srcrega = rs;
                        srcregb = rt;
                        destreg = '0;
                    end    
                    `F_DIVU: begin
                        ctl.op = DIVU;
                        ctl.hiwrite = 1'b1;
                        ctl.lowrite = 1'b1;
                        ctl.alusrc = REGB;
                        srcrega = rs;
                        srcregb = rt;
                        destreg = '0;
                    end   
                    `F_MULT: begin
                        ctl.op = MULT;
                        ctl.hiwrite = 1'b1;
                        ctl.lowrite = 1'b1;
                        ctl.alusrc = REGB;
                        srcrega = rs;
                        srcregb = rt;
                        destreg = '0;
                    end   
					`F_MULTU:begin
                        ctl.op = MULTU;
                        ctl.hiwrite = 1'b1;
                        ctl.lowrite = 1'b1;
                        ctl.alusrc = REGB;
                        srcrega = rs;
                        srcregb = rt;
                        destreg = '0;
                    end	
					`F_AND:begin
                        ctl.op = AND;
                        ctl.alufunc = ALU_AND;
                        ctl.regwrite = 1'b1;
                        ctl.alusrc = REGB;
                        srcrega = rs;
                        srcregb = rt;
                        destreg = rd;
                    end		
					`F_NOR:begin
                        ctl.op = NOR;
                        ctl.alufunc = ALU_NOR;
                        ctl.regwrite = 1'b1;
                        ctl.alusrc = REGB;
                        srcrega = rs;
                        srcregb = rt;
                        destreg = rd;
                    end		
					`F_OR:begin
                        ctl.op = OR;
                        ctl.alufunc = ALU_OR;
                        ctl.regwrite = 1'b1;
                        ctl.alusrc = REGB;
                        srcrega = rs;
                        srcregb = rt;
                        destreg = rd;
                    end		
					`F_XOR:begin
                        ctl.op = XOR;
                        ctl.alufunc = ALU_XOR;
                        ctl.regwrite = 1'b1;
                        ctl.alusrc = REGB;
                        srcrega = rs;
                        srcregb = rt;
                        destreg = rd;
                    end		
					`F_SLLV:begin
                        ctl.op = SLLV;
                        ctl.alufunc = ALU_SLL;
                        ctl.regwrite = 1'b1;
                        ctl.alusrc = REGB;
                        srcrega = rs;
                        srcregb = rt;
                        destreg = rd;
                    end	
					`F_SLL:begin
                        ctl.op = SLL;
                        ctl.alufunc = ALU_SLL;
                        ctl.regwrite = 1'b1;
                        ctl.alusrc = REGB;
                        ctl.shamt_valid = 1'b1;
                        srcrega = '0;
                        srcregb = rt;
                        destreg = rd;
                    end		
					`F_SRAV:begin
                        ctl.op = SRAV;
                        ctl.alufunc = ALU_SRA;
                        ctl.regwrite = 1'b1;
                        ctl.alusrc = REGB;
                        srcrega = rs;
                        srcregb = rt;
                        destreg = rd;
                        
                    end	
					`F_SRA:begin
                        ctl.op = SRA;
                        ctl.alufunc = ALU_SRA;
                        ctl.regwrite = 1'b1;
                        ctl.alusrc = REGB;
                        ctl.shamt_valid = 1'b1;
                        srcrega = '0;
                        srcregb = rt;
                        destreg = rd;
                    end		
					`F_SRLV:begin
                        ctl.op = SRLV;
                        ctl.alufunc = ALU_SRL;
                        ctl.regwrite = 1'b1;
                        ctl.alusrc = REGB;
                        srcrega = rs;
                        srcregb = rt;
                        destreg = rd;

                    end	
					`F_SRL:begin
                        ctl.op = SRL;
                        ctl.alufunc = ALU_SRL;
                        ctl.regwrite = 1'b1;
                        ctl.alusrc = REGB;
                        ctl.shamt_valid = 1'b1;
                        srcrega = '0;
                        srcregb = rt;
                        destreg = rd;
                    end		
					`F_JR:begin
                        ctl.op = JR;
                jump='1;
                        ctl.jump = 1'b1;
                        ctl.jr = 1'b1;
                        srcrega = rs;
                        srcregb = 'b0;
                        destreg = 'b0;
                    end		
					`F_JALR:begin
                        ctl.op = JALR;
                jump='1;
                        ctl.jump = 1'b1;
                        ctl.jr = 1'b1;
                        ctl.regwrite = 1'b1;
                        ctl.is_link = 'b1;
                        srcrega = rs;
                        srcregb = 'b0;
                        destreg = rd;
                    end	
					`F_MFHI:begin
                        ctl.op = MFHI;
                        ctl.regwrite = 1'b1;
                        ctl.alufunc = ALU_PASSA;
                        ctl.hitoreg = 1'b1;
                        srcrega = 'b0;
                        srcregb = 'b0;
                        destreg = rd;
                    end	
					`F_MFLO:begin
                        ctl.op = MFLO;
                        ctl.regwrite = 1'b1;
                        ctl.alufunc = ALU_PASSB;
                        ctl.lotoreg = 1'b1;
                        srcrega = 'b0;
                        srcregb = 'b0;
                        destreg = rd;
                    end	
					`F_MTHI:begin
                        ctl.op = MTHI;
                        ctl.hiwrite = 1'b1;
                        ctl.alufunc = ALU_PASSA;
                        srcrega = rs;
                        srcregb = 'b0;
                        destreg = 'b0;
                    end	
					`F_MTLO:begin
                        ctl.op = MTLO;
                        ctl.lowrite = 1'b1;
                        ctl.alufunc = ALU_PASSA;
                        srcrega = rs;
                        srcregb = 'b0;
                        destreg = 'b0;
                    end	
					`F_BREAK:begin
                        ctl.op = BREAK;
                        ctl.alufunc = ALU_PASSA;
                        cp0_ctl.ctype=EXCEPTION;
                        cp0_ctl.valid='1;
                        cp0_ctl.etype.trap='1;
                        ctl.is_bp = 1'b1;
                        srcrega = 'b0;
                        srcregb = 'b0;
                        destreg = 'b0;
                    end	
					`F_SYSCALL:begin
                        ctl.op = SYSCALL;
                        cp0_ctl.ctype=EXCEPTION;
                        cp0_ctl.valid='1;
                        cp0_ctl.etype.syscall='1;
                        ctl.alufunc = ALU_PASSA;
                        ctl.is_sys = 1'b1;
                        srcrega = 'b0;
                        srcregb = 'b0;
                        destreg = 'b0;
                    end	
                    default: begin
                        exception_ri = 1'b1;
                        ctl.op = RESERVED;
                        ctl.alufunc = ALU_PASSA;
                        srcrega = 'b0;
                        srcregb = 'b0;
                        destreg = 'b0;
                cp0_ctl.ctype=EXCEPTION;
                    end
                endcase
            end
            default: begin
                exception_ri = 1'b1;
                ctl.op = RESERVED;
                ctl.alufunc = ALU_PASSA;
                srcrega = 'b0;
                srcregb = 'b0;
                destreg = 'b0;
                cp0_ctl.ctype=EXCEPTION;
            end
        endcase
        end
        cp0_ctl.etype.reserveInstr=exception_ri;
        
	end
endmodule