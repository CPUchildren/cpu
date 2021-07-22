`timescale 1ns / 1ps
// sign extend
module signext (
    input wire [15:0]a, // input wire [15:0]a
    input wire [1:0] type, //op[3:2] for andi type
    output wire [31:0]y // output wire [31:0]
);
    assign y = (type==2'b11)?  {{16{1'b0}},a}:{{16{a[15]}},a};
endmodule