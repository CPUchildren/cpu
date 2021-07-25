//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2014 leishangwen@163.com                       ////
////                                                              ////
//// This source file may be used and distributed without         ////
//// restriction provided that this copyright statement is not    ////
//// removed from the file and that any derivative work contains  ////
//// the original copyright notice and the associated disclaimer. ////
////                                                              ////
//// This source file is free software; you can redistribute it   ////
//// and/or modify it under the terms of the GNU Lesser General   ////
//// Public License as published by the Free Software Foundation; ////
//// either version 2.1 of the License, or (at your option) any   ////
//// later version.                                               ////
////                                                              ////
//// This source is distributed in the hope that it will be       ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
//// PURPOSE.  See the GNU Lesser General Public License for more ////
//// details.                                                     ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////
// Module:  div
// File:    div.v
// Author:  Lei Silei
// E-mail:  leishangwen@163.com
// Description:除法模块
// Revision: 1.0
//////////////////////////////////////////////////////////////////////

`include "defines.vh"

module div(

input wire clk,
input wire rst,ena,

input wire signed_div_i, 
input wire[31:0] opdata1_i,
input wire[31:0] opdata2_i,
input wire start_i,
input wire annul_i,

output reg [1:0] state,
output reg[63:0] result_o,
output reg ready_o
);

wire[32:0] div_temp;
reg[5:0] cnt;
reg[64:0] dividend;
//reg[1:0] state;
reg[31:0] divisor;	 
reg[31:0] temp_op1;
reg[31:0] temp_op2;
//reg[31:0] opdata1_i;
//reg[31:0] opdata2_i;
reg sign1,sign2;

assign div_temp = {1'b0,dividend[63:32]} - {1'b0,divisor};

//always @(posedge clk) begin
//    if(rst) begin 
//        opdata1_i <= 32'h00000000;
//        opdata2_i <= 32'h00000000;
//    end

//else if (ena) begin
//        opdata1_i <= temp_opdata1_i;
//        opdata2_i <= temp_opdata2_i;
//     end
//end

always @ (posedge clk) begin
    if (rst == `RstEnable) begin
        state <= `DivFree;
        ready_o <= `DivResultNotReady;
        result_o <= {`ZeroWord,`ZeroWord};
        sign1 <= 1'b0;
        sign2 <= 1'b0;
    end else begin
      case (state)
        `DivFree:			begin               //DivFree state
            if(start_i == `DivStart && annul_i == 1'b0) begin
                if(opdata2_i == `ZeroWord) begin
                    state <= `DivByZero;
                end else begin
                    state <= `DivOn;
                    cnt <= 6'b000000;
                    if(signed_div_i == 1'b1 && opdata1_i[31] == 1'b1 ) begin
                        temp_op1 = ~opdata1_i + 1;
                        sign1 <= opdata1_i[31];
                    end else begin
                        temp_op1 = opdata1_i;
                        sign1 <= 1'b0;
                    end
                    if(signed_div_i == 1'b1 && opdata2_i[31] == 1'b1 ) begin
                        temp_op2 = ~opdata2_i + 1;
                        sign2 <= opdata2_i[31];
                    end else begin
                        temp_op2 = opdata2_i;
                        sign2 <= 1'b0;
                    end
                    dividend <= {`ZeroWord,`ZeroWord};
                    dividend[32:1] <= temp_op1;
                    divisor <= temp_op2;
                    $display("除法开始");
         end
      end else begin
                    ready_o <= `DivResultNotReady;
                    result_o <= {`ZeroWord,`ZeroWord};
              end          	
        end
        `DivByZero:		begin               //DivByZero??
            dividend <= {`ZeroWord,`ZeroWord};
            state <= `DivEnd;		 		
        end
        `DivOn:				begin               //DivOn??
            $display("除法执行");
            if(annul_i == 1'b0) begin
                if(cnt != 6'b100000) begin
                    if(div_temp[32] == 1'b1) begin
                        dividend <= {dividend[63:0] , 1'b0};
                    end else begin
                        dividend <= {div_temp[31:0] , dividend[31:0] , 1'b1};
                    end
                    cnt <= cnt + 1;
                end else begin
                    // if((signed_div_i == 1'b1) && ((opdata1_i[31] ^ opdata2_i[31]) == 1'b1)) begin
                    if((signed_div_i == 1'b1) && ((sign1 ^ sign2) == 1'b1)) begin
                        // 商 lo
                        dividend[31:0] <= (~dividend[31:0] + 1);
                    end
                    // if((signed_div_i == 1'b1) && ((opdata1_i[31] ^ dividend[64]) == 1'b1)) begin 
                    if((signed_div_i == 1'b1) && ((sign1 ^ dividend[64]) == 1'b1)) begin              
                        // 余数 hi
                        dividend[64:33] <= (~dividend[64:33] + 1);
                    end
                    state <= `DivEnd;
                    cnt <= 6'b000000;            	
                end
            end else begin
                state <= `DivFree;
            end	
        end
        `DivEnd:			begin               //DivEnd??
            result_o <= {dividend[64:33], dividend[31:0]};  
            ready_o <= `DivResultReady;
            if(start_i == `DivStop) begin
                state <= `DivFree;
                ready_o <= `DivResultNotReady;
                result_o <= {`ZeroWord,`ZeroWord};       	
            end		  	
        end
      endcase
    end
end
always @(posedge clk) begin
//        $display("alucontrolE: %b",alucontrolE);
//        $display("hi: %h", hilo_i[63:32]);
//       $display("lo: %h", hilo_i[31:0]);
//       $display("instrD: %b", instrD);
//       $display("stallD: %b", stallD);
//       $display("rd1E: %h", rd1E);
//       $display("rd2E: %h", rd2E);
//        if( state==2'b11) begin
//        $display("======================");
//       $display("ready_o: %b", ready_o);
//       $display("opdata1_i: %d", opdata1_i);
//       $display("opdata2_i: %d", opdata2_i);
//       $display("start_i: %h", start_i);
//       $display("annul_i: %h", annul_i);
//       $display("cnt: %b", cnt);
//       $display("signed_div_i: %h", signed_div_i);
//        $display("state: %b", state);
//        $display("dividend[64:33]: %h", dividend[64:33]);
//        $display("dividend[31:0]: %h", dividend[31:0]);
//        $display("result_o: %h", result_o);
        
//        $display("======================");
//        end
end
endmodule