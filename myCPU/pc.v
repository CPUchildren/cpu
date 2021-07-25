`timescale 1ns/1ps
// PC模块，一个D触发�?
module pc (
    input wire clk,rst,ena,
    input wire[31:0]din,
    output reg[31:0]dout
);
    initial begin
        dout <= 32'hbfc00000;
    end
    always @(posedge clk) begin
        if(rst) dout <= 32'hbfc00000;
        else if(ena) dout <= din;
    end
endmodule