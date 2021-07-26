`timescale 1ns/1ps
`include "defines.vh"
module main_dec(
    input wire clk,rst,flushE,stallE,
    input wire [7:0]exceptM,
    input wire [31:0]instrD,
    output wire regwriteW,regdstE,alusrcAE,alusrcBE,branchD,memWriteM,memtoRegW,
    output wire regwriteE,regwriteM,memtoRegE,memtoRegM,hilowriteM,cp0writeM,
    output wire jumpD,balD,balE,balW,jalD,jalE,jalW,jrD,jrE,jrW,
    output reg invalid
);
    // Decoder
    wire [5:0]op;
    wire [5:0]funct;
    wire [4:0]rt;
    wire [4:0]rs;
    reg [12:0]signsD;
    wire [12:0]signsE,signsW,signsM;
    wire ena;

    assign op = instrD[31:26];
    assign funct = instrD[5:0];
    assign rt = instrD[20:16];
    assign rs = instrD[25:21];
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
    assign cp0writeM = signsM[11];  // CP0  E读取，M写回，避免数据冒险处理
    assign balD=signsD[10];
    assign balE=signsE[10];
    assign balW=signsW[10];
    assign jalD=signsD[8];
    assign jalE=signsE[8];
    assign jalW=signsW[8];
    assign jrD=signsD[9];
    assign jrE=signsE[9];
    assign jrW=signsW[9];


    assign ena = 1'b1;

    // signsD = {12cp0write,11hilowrite,10bal,9jr,8jal,7alusrcA,6regwrite,5regdst,,4alusrcB,3branch,2memWrite,1memtoReg,0jump}
    always @(*) begin
        invalid <= 1'b0;
        case(op)
            `OP_R_TYPE:
                case (funct)
                    //????
                    `FUN_SLL   : signsD <= 13'b0000011100000 ;
                    `FUN_SLLV  : signsD <= 13'b0000001100000 ;
                    `FUN_SRL   : signsD <= 13'b0000011100000 ;
                    `FUN_SRLV  : signsD <= 13'b0000001100000 ;
                    `FUN_SRA   : signsD <= 13'b0000011100000 ;
                    `FUN_SRAV  : signsD <= 13'b0000001100000 ;
                    //???????
                    `FUN_AND   : signsD <= 13'b0000001100000;    //and
                    `FUN_OR    : signsD <= 13'b0000001100000;    //or
                    `FUN_XOR   : signsD <= 13'b0000001100000;   //xor
                    `FUN_NOR   : signsD <= 13'b0000001100000;   //nor
                    `FUN_SLT   : signsD <= 13'b0000001100000;   //slt
                    `FUN_SLTU  : signsD <= 13'b0000001100000;   //sltu
                    `FUN_ADD   : signsD <= 13'b0000001100000;   //add
                    `FUN_ADDU  : signsD <= 13'b0000001100000;   //addu
                    `FUN_SUB   : signsD <= 13'b0000001100000;   //sub
                    `FUN_SUBU  : signsD <= 13'b0000001100000;   //subu
                    `FUN_MULT  : signsD <= 13'b0100001100000;   //mult
                    `FUN_MULTU : signsD <= 13'b0100001100000;  //multu
                    `FUN_DIV   : signsD <= 13'b0100001100000;   //div
                    `FUN_DIVU  : signsD <= 13'b0100001100000;   //divu
                    // ????
                    `FUN_JR    : signsD <= 13'b0001000000001;
                    `FUN_JALR  : signsD <= 13'b0001001100000;
                    //??????
                    `FUN_MFHI  : signsD <= 13'b0000001100000;
                    `FUN_MFLO  : signsD <= 13'b0000001100000;
                    `FUN_MTHI  : signsD <= 13'b0100000000000;
                    `FUN_MTLO  : signsD <= 13'b0100000000000;
                    // 内陷指令
                    `FUN_SYSCALL:signsD <= 13'b0000000000000;
                    `FUN_BREAK  :signsD <= 13'b0000000000000;
                    // TODO ???r-type?????????????????
                    default: begin 
                        signsD <= 13'b0000001100000;
                        invalid <= 1'b1;
                    end
                endcase
            // ????
            `OP_LB    : signsD <= 13'b0000001010010;
            `OP_LBU   : signsD <= 13'b0000001010010;
            `OP_LH    : signsD <= 13'b0000001010010;
            `OP_LHU   : signsD <= 13'b0000001010010;
            `OP_LW    : signsD <= 13'b0000001010010; // lw
            `OP_SB    : signsD <= 13'b0000000010110;
            `OP_SH    : signsD <= 13'b0000000010110;
            `OP_SW    : signsD <= 13'b0000000010110; // sw
            //arithmetic type
            `OP_ADDI  : signsD <= 13'b0000001010000; // addi
            `OP_ADDIU : signsD <= 13'b0000001010000; // addiu     //alusrcA???1
            `OP_SLTI  : signsD <= 13'b0000001010000;// slti
            `OP_SLTIU : signsD <= 13'b0000001010000; // sltiu
            //logical type
            `OP_ANDI  : signsD <= 13'b0000001010000; // andi
            `OP_ORI   : signsD <= 13'b0000001010000; // ori
            `OP_XORI  : signsD <= 13'b0000001010000; // xori
            `OP_LUI   : signsD <= 13'b0000001010000; // lui
            
            // ??????
            // alusrcA,regwrite,regdst,alusrcB,branch,memWrite,memtoReg,jump
            // TODO ????????
            `OP_BEQ   : signsD <= 13'b0000000001000; // BEQ
            `OP_BNE   : signsD <= 13'b0000000001000; // BNE
            `OP_BGTZ  : signsD <= 13'b0000000001000; // BGTZ
            `OP_BLEZ  : signsD <= 13'b0000000001000; // BLEZ  
            `OP_SPEC_B:     // BGEZ,BLTZ,BGEZAL,BLTZAL
                case(rt)
                    `RT_BGEZ : signsD  <= 13'b0000000001000;
                    `RT_BLTZ : signsD  <= 13'b0000000001000;
                    `RT_BGEZAL: signsD <= 13'b0010001001000;
                    `RT_BLTZAL: signsD <= 13'b0010001001000;
                    default: invalid <= 1'b1;
                endcase
            `OP_J     : signsD <= 13'b0000000000001; // J     
            `OP_JAL   : signsD <= 13'b0000101000000; 
            // 特权指令
            `OP_SPECIAL_INST:
                case (rs)
                    `RS_MFC0: signsD <= 13'b0000001000000;
                    `RS_MTC0: signsD <= 13'b1000000000000;
                    default : signsD <= 13'b0000000000000;
                endcase
            default: invalid <= 1'b1;
        endcase
    end
   
    // Execute
    flopenrc #(12) dff1E(clk,rst,flushE|(|exceptM),~stallE,signsD,signsE);
    // Mem
    // flopenr #(12) dff1M(clk,rst,ena,signsE,signsM);
    flopenrc #(12) dff1M(clk,rst,(|exceptM),ena,signsE,signsM);
    // Write
    // flopenr #(12) dff1W(clk,rst,ena,signsM,signsW);    
    flopenrc #(12) dff1W(clk,rst,(|exceptM),ena,signsM,signsW);
    
endmodule
