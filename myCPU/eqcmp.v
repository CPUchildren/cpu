`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/07/22 13:28:59
// Design Name: 
// Module Name: eqcmp
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module eqcmp(
    input [31:0] a,b,
    input wire [5:0] op,
    input wire [4:0] rt,
    output wire y
    );
    assign y=(op==6'b000100)?(a==b)://beq
             (op==6'b000101)?(a!=b)://bne
             (op==6'b000111)?((a[31]==1'b0)&&(a!=32'h0))://bgtz
             (op==6'b000110)?((a[31]==1'b1)||(a==32'h0))://blez
             ((op==6'b000001)&&((rt==5'b00001)||(rt==5'b10001)))?(a[31]==1'b0)://bgez,bgezal
             ((op==6'b000001)&&((rt==5'b00000)||(rt==5'b10000)))?((a[31]==1'b1)||(a!=32'h0)):0;//bltz,bltazl
endmodule
