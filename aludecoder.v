`include "defines.vh"
module alu_dec (
    input wire clk, rst,flushE, stallE,
    input wire [31:0]instrD,
    output wire[7:0]aluopE
);  

    wire[5:0]op;
    wire[5:0]funct;
    wire[4:0]rt;
    wire[4:0]rs;
    reg[7:0]aluopD;

    wire ena;

    assign op = instrD[31:26];
    assign funct = instrD[5:0];
    assign rs = instrD[25:21];
    assign rt = instrD[20:16];

    assign ena = 1'b1;

    always @(*) begin
        case (op)
            `OP_R_TYPE:
                case (funct)
                    // logic instr
                    `FUN_AND   : aluopD <= `ALUOP_AND   ;
                    `FUN_OR    : aluopD <= `ALUOP_OR    ;
                    `FUN_XOR   : aluopD <= `ALUOP_XOR   ;
                    `FUN_NOR   : aluopD <= `ALUOP_NOR   ;
                    // arith instr
                    `FUN_SLT   : aluopD <= `ALUOP_SLT   ;
                    `FUN_SLTU  : aluopD <= `ALUOP_SLTU  ;
                    `FUN_ADD   : aluopD <= `ALUOP_ADD   ;
                    `FUN_ADDU  : aluopD <= `ALUOP_ADDU  ;
                    `FUN_SUB   : aluopD <= `ALUOP_SUB   ;
                    `FUN_SUBU  : aluopD <= `ALUOP_SUBU  ;
                    `FUN_MULT  : aluopD <= `ALUOP_MULT  ;
                    `FUN_MULTU : aluopD <= `ALUOP_MULTU ;
                    `FUN_DIV   : aluopD <= `ALUOP_DIV  ;
                    `FUN_DIVU  : aluopD <= `ALUOP_DIVU  ;
                    // shift instr
                    `FUN_SLL   : aluopD <= `ALUOP_SLL   ;
                    `FUN_SLLV  : aluopD <= `ALUOP_SLLV  ;
                    `FUN_SRL   : aluopD <= `ALUOP_SRL   ;
                    `FUN_SRLV  : aluopD <= `ALUOP_SRLV  ;
                    `FUN_SRA   : aluopD <= `ALUOP_SRA   ;
                    `FUN_SRAV  : aluopD <= `ALUOP_SRAV  ;
                    // move instr
                    `FUN_MFHI  : aluopD <= `ALUOP_MFHI  ;
                    `FUN_MFLO  : aluopD <= `ALUOP_MFLO  ;
                    `FUN_MTHI  : aluopD <= `ALUOP_MTHI  ;
                    `FUN_MTLO  : aluopD <= `ALUOP_MTLO  ;
                    default: aluopD <= 8'b00000000;
                endcase
            //logic immediate
            `OP_ANDI: aluopD <= `ALUOP_ANDI;
            `OP_XORI: aluopD <= `ALUOP_XORI;
            `OP_LUI : aluopD <= `ALUOP_LUI;
            `OP_ORI : aluopD <= `ALUOP_ORI;
            //arith immediate
            `OP_ADDI: aluopD <= `ALUOP_ADDI;
            `OP_ADDIU: aluopD <= `ALUOP_ADDIU;
            `OP_SLTI: aluopD <= `ALUOP_SLTI;
            `OP_SLTIU: aluopD <= `ALUOP_SLTIU;
            // load/store instr
            `OP_LB:   aluopD <= `ALUOP_ADD;
            `OP_LBU:  aluopD <= `ALUOP_ADD;
            `OP_LH:   aluopD <= `ALUOP_ADD;
            `OP_LHU:  aluopD <= `ALUOP_ADD;
            `OP_LW:   aluopD <= `ALUOP_ADD;
            `OP_SB:   aluopD <= `ALUOP_ADD;
            `OP_SH:   aluopD <= `ALUOP_ADD;
            `OP_SW:   aluopD <= `ALUOP_ADD;
            // 特权指令
            `OP_SPECIAL_INST:
                case (rs)
                    `RS_MFC0: aluopD <= `ALUOP_MFC0;
                    default : aluopD <= 8'b00000000;
                endcase
            default: aluopD <= 8'b00000000;
        endcase
    end
    // 
    flopenrc #(8) dff2E(clk,rst,flushE,~stallE,aluopD,aluopE);
endmodule