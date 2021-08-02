`timescale 1ns/1ps
`include "defines.vh"
module main_dec(
    input wire clk,rst,
    input wire flushE,flushM,flushW,
    input wire stallE,stallM,stallW,
    input  wire [5:0] op,funct,
    input  wire [4:0] rs,rt,
    output wire regwriteW,regdstE,alusrcAE,alusrcBE,branchD,memWriteM,memtoRegW,
    output wire regwriteE,regwriteM,memtoRegE,memtoRegM,hilowriteM,cp0writeM,
    output wire jumpD,balD,balE,balW,jalD,jalE,jalW,jrD,jrE,jrW,memenM,
    output reg invalid
);
    // Decoder
    reg [13:0]signsD;
    wire [13:0]signsE,signsW,signsM;
    wire clear,ena;
    
    assign regwriteW = signsW[6];
    assign regwriteE = signsE[6];
    assign regwriteM = signsM[6];
    assign regdstE = signsE[5];
    assign alusrcAE = signsE[7];
    assign alusrcBE = signsE[4];
    assign branchD = signsD[3];
    assign memWriteM = signsM[2];
    assign memtoRegW = signsW[1];
    assign memtoRegE = signsE[1];
    assign memtoRegM = signsM[1];
    assign jumpD = signsD[0];
    assign hilowriteM = signsM[11]; // hilo E读取，M写回，避免数据冒险处理
    assign cp0writeM = signsM[12];  // CP0  E读取，M写回，避免数据冒险处理
    assign balD=signsD[10];
    assign balE=signsE[10];
    assign balW=signsW[10];
    assign jalD=signsD[8];
    assign jalE=signsE[8];
    assign jalW=signsW[8];
    assign jrD=signsD[9];
    assign jrE=signsE[9];
    assign jrW=signsW[9];
    assign memenM=signsM[13];

    assign ena   = 1'b1;
    assign clear = 1'b0;

    // signsD = {13memen,12cp0write,11hilowrite,10bal,9jr,8jal,7alusrcA,6regwrite,5regdst,,4alusrcB,3branch,2memWrite,1memtoReg,0jump}
    always @(*) begin
        invalid <= 1'b0;
        case(op)
            `OP_R_TYPE:
                case (funct)
                    // logic
                    `FUN_AND   : signsD <= 14'b00000001100000;    //and
                    `FUN_OR    : signsD <= 14'b00000001100000;    //or
                    `FUN_XOR   : signsD <= 14'b00000001100000;   //xor
                    `FUN_NOR   : signsD <= 14'b00000001100000;   //nor
                    // arith
                    `FUN_SLT   : signsD <= 14'b00000001100000;   //slt
                    `FUN_SLTU  : signsD <= 14'b00000001100000;   //sltu
                    `FUN_ADD   : signsD <= 14'b00000001100000;   //add
                    `FUN_ADDU  : signsD <= 14'b00000001100000;   //addu
                    `FUN_SUB   : signsD <= 14'b00000001100000;   //sub
                    `FUN_SUBU  : signsD <= 14'b00000001100000;   //subu
                    `FUN_MULT  : signsD <= 14'b00100001100000;   //mult
                    `FUN_MULTU : signsD <= 14'b00100001100000;  //multu
                    `FUN_DIV   : signsD <= 14'b00100001100000;   //div
                    `FUN_DIVU  : signsD <= 14'b00100001100000;   //divu
                    // shift
                    `FUN_SLL   : signsD <= 14'b00000011100000 ;
                    `FUN_SLLV  : signsD <= 14'b00000001100000 ;
                    `FUN_SRL   : signsD <= 14'b00000011100000 ;
                    `FUN_SRLV  : signsD <= 14'b00000001100000 ;
                    `FUN_SRA   : signsD <= 14'b00000011100000 ;
                    `FUN_SRAV  : signsD <= 14'b00000001100000 ;
                    // jump R
                    `FUN_JR    : signsD <= 14'b00001000000001;
                    `FUN_JALR  : signsD <= 14'b00001001100000;
                    // move
                    `FUN_MFHI  : signsD <= 14'b00000001100000;
                    `FUN_MFLO  : signsD <= 14'b00000001100000;
                    `FUN_MTHI  : signsD <= 14'b00100000000000;
                    `FUN_MTLO  : signsD <= 14'b00100000000000;
                    // 内陷指令
                    `FUN_SYSCALL:signsD <= 14'b00000000000000;
                    `FUN_BREAK  :signsD <= 14'b00000000000000;
                    default: begin 
                        signsD <= 14'b00000001100000;
                        invalid <= 1'b1;
                    end
                endcase
            // lsmen
            `OP_LB    : signsD <= 14'b10000001010010;
            `OP_LBU   : signsD <= 14'b10000001010010;
            `OP_LH    : signsD <= 14'b10000001010010;
            `OP_LHU   : signsD <= 14'b10000001010010;
            `OP_LW    : signsD <= 14'b10000001010010; // lw
            `OP_SB    : signsD <= 14'b10000000010110;
            `OP_SH    : signsD <= 14'b10000000010110;
            `OP_SW    : signsD <= 14'b10000000010110; // sw
            // arith imme
            `OP_ADDI  : signsD <= 14'b00000001010000; // addi
            `OP_ADDIU : signsD <= 14'b00000001010000; // addiu
            `OP_SLTI  : signsD <= 14'b00000001010000;// slti
            `OP_SLTIU : signsD <= 14'b00000001010000; // sltiu
            // logic imme
            `OP_ANDI  : signsD <= 14'b00000001010000; // andi
            `OP_ORI   : signsD <= 14'b00000001010000; // ori
            `OP_XORI  : signsD <= 14'b00000001010000; // xori
            `OP_LUI   : signsD <= 14'b00000001010000; // lui            
            // branch
            `OP_BEQ   : signsD <= 14'b00000000001000; // BEQ
            `OP_BNE   : signsD <= 14'b00000000001000; // BNE
            `OP_BGTZ  : signsD <= 14'b00000000001000; // BGTZ
            `OP_BLEZ  : signsD <= 14'b00000000001000; // BLEZ  
            `OP_SPEC_B:     // BGEZ,BLTZ,BGEZAL,BLTZAL
                case(rt)
                    `RT_BGEZ : signsD  <= 14'b00000000001000;
                    `RT_BLTZ : signsD  <= 14'b00000000001000;
                    `RT_BGEZAL: signsD <= 14'b00010001001000;
                    `RT_BLTZAL: signsD <= 14'b00010001001000;
                    default: invalid <= 1'b1;
                endcase
            // jump
            `OP_J     : signsD <= 14'b00000000000001; // J     
            `OP_JAL   : signsD <= 14'b00000101000000; 
            // special
            `OP_SPECIAL_INST:
                case (rs)
                    `RS_MFC0: signsD <= 14'b00000001000000;
                    `RS_MTC0: signsD <= 14'b01000000000000;
                    default : signsD <= 14'b00000000000000;
                endcase
            default: invalid <= 1'b1;
        endcase
    end
   
    flopenrc #(14) dff1E(clk,rst,flushE,~stallE,signsD,signsE);
    flopenrc #(14) dff1M(clk,rst,flushM,~stallM,signsE,signsM);
    flopenrc #(14) dff1W(clk,rst,flushW,~stallW,signsM,signsW);  // W阶段异常刷新 
    
endmodule
