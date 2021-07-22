`timescale 1ns / 1ps
`include "instrdefines.vh"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2017/12/12 11:26:03
// Design Name: 
// Module Name: hilo_reg
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


module hilo_reg(
	input wire clk,rst,we,		// 时钟,复位,使能
	// input wire[31:0] hi,lo,
	input wire[63:0] hilo_i,
	
	// TODO 为啥感觉具体的hilo操作直接在alu里面进行了
	// output reg[31:0] hilo_res,
	output reg[63:0] hilo  // hilo current data
    );
	
	// 注意，要相对具体传入的clk判断，比如这次传入的是~clk
	always @(negedge clk) begin
		if(rst) begin
			// hi_o <= `ZeroWord;
			// lo_o <= `ZeroWord;
			hilo <= {`ZeroWord,`ZeroWord};
		end else if (we) begin
			// hi_o <= hi;
			// lo_o <= lo;
			hilo <= hilo_i;
		end
	end
endmodule



// module hilo_reg(
//                 input wire        clk,rst,we, //both write lo and hi
//                 input wire [1:0] mfhi_loM,

//                 input wire [63:0] hilo_i,
//                 output wire [31:0] hilo_o,
//                 output reg [63:0] hilo
//                 );

//    // wire [63:0] hilo_ii;
//    always @(posedge clk) begin
//       if(rst)
//          hilo <= 0;
//       else if(we)
//          hilo <= hilo_i;
//       else
//          hilo <= hilo;
//    end

//    // assign hilo_ii = ( {64{~rst & we}} & hilo_i );

//    // 读hilo逻辑；
//    wire mfhi, mflo;
//    assign mfhi = mfhi_loM[1];
//    assign mflo = mfhi_loM[0];

//    assign hilo_o = ({32{mfhi}} & hilo[63:32]) | ({32{mflo}} & hilo[31:0]);
// endmodule

