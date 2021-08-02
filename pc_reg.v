`timescale 1ns/1ps
module pc_reg (
    input wire clk,rst,ena,
    input wire[31:0]din,
    
    output wire pc_en,
    output reg[31:0]dout
);
    initial begin
        dout <= 32'hbfc00000;
    end

    assign pc_en = 1'b1;
    
    always @(posedge clk) begin
        if(rst) dout <= 32'hbfc00000;
        else if(ena) dout <= din;
    end
endmodule