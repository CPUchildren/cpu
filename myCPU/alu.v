`timescale 1ns / 1ps
`include "instrdefines.vh"
// Module Name: alu
// Description: alu基本运算

module alu(
    input  wire [31:0]a,
    input  wire [31:0]b,
    input  wire [7:0]aluop,
    input  wire  [63:0]hilo, // hilo source data

    output reg [31:0]y,
    output reg [63:0]aluout_64,
    output wire overflow,
    output wire zero
    );
    
    assign zero = (y == 32'b0);
    always @(*) begin
        case (aluop)
            //算术指令
            `ALUOP_ADD   : y <= a + b;
            `ALUOP_ADDU  : y <= a + b;
            `ALUOP_ADDI  : y <= a + b;
            `ALUOP_ADDIU : y <= a + b;
            `ALUOP_SUB   : y <= a - b;
            `ALUOP_SUBU  : y <= a - b;
            // TODO 这里是不是可以只用一个aluop
            `ALUOP_SLT   : y <= $signed(a) < $signed(b);
            `ALUOP_SLTU  : y <= a < b;
            `ALUOP_SLTI  : y <= a < b;
            `ALUOP_SLTIU : y <= a < b;
            
            //逻辑指令
            `ALUOP_AND   : y <= a & b;
            `ALUOP_OR    : y <= a | b;
            `ALUOP_NOR   : y <= ~ (a | b);
            `ALUOP_XOR   : y <= a ^ b;
            `ALUOP_ANDI  : y <= a & b;
            `ALUOP_ORI   : y <= a | b;
            `ALUOP_XORI  : y <= a ^ b;
            `ALUOP_LUI   : y <={b[15:0],16'b0};
            
            // 移位指令
            `ALUOP_SLL   : y <= b << a[4:0];
            `ALUOP_SLLV: y <= b << a[4:0];
            `ALUOP_SRL: y <= b >> a[4:0];
            `ALUOP_SRLV: y <= b >> a[4:0];
            `ALUOP_SRA: y <= $signed(b) >>> a[4:0];
            `ALUOP_SRAV: y <= $signed(b) >>> a[4:0];
            // 分支指令
//            `ALUOP_BG
            
            // 数据移动指令
            `ALUOP_MTHI: aluout_64 <= {a,hilo[31:0]};
            `ALUOP_MTLO: aluout_64 <= {hilo[63:32],a};
            `ALUOP_MFHI: y <= hilo[63:32];
            `ALUOP_MFLO: y <= hilo[31:0];
            default      : y <= 32'b0;
        endcase
    end

endmodule
