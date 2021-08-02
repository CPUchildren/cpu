`timescale 1ns / 1ps
`include "defines.vh"

module hilo_reg(
	input wire clk,rst,we,		// ʱ��,��λ,ʹ��
	// input wire[31:0] hi,lo,
	input wire[63:0] hilo_i,
	
	// output reg[31:0] hilo_res,  // �����hilo����ֱ����alu���������
	output reg[63:0] hilo  // hilo current data
    );
	
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

//    // ��hilo�߼���
//    wire mfhi, mflo;
//    assign mfhi = mfhi_loM[1];
//    assign mflo = mfhi_loM[0];

//    assign hilo_o = ({32{mfhi}} & hilo[63:32]) | ({32{mflo}} & hilo[31:0]);
// endmodule

