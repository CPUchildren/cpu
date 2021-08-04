`timescale 1ns / 1ps
`include "defines.vh"

module alu(
    input  wire clk,rst,
    input  wire div_ready, 
    input  wire [1:0] state_div,
    input  wire [7:0]aluop,
    input  wire [31:0]a,
    input  wire [31:0]b,
    input  wire [31:0]cp0_data_o,
    input  wire  [63:0]hilo, // hilo source data

    output reg start_div,signed_div,stall_div,
    output reg [31:0] y,
    output wire [63:0]aluout_64,
    output reg overflow,
    output wire zero
    );
    reg [63:0] temp_aluout_64;
    wire [31:0] multa,multb;
    wire [63:0] div_result;
    //multiply module
    assign multa = (aluop == `ALUOP_MULT) && (a[31] == 1'b1) ? (~a + 1) : a;
    assign multb = (aluop == `ALUOP_MULT) && (b[31] == 1'b1) ? (~b + 1) : b;
    assign zero = (y == 32'b0);
    
    assign aluout_64= (div_ready) ?  div_result : temp_aluout_64;

    always @(*) begin
        stall_div<= 1'b0;
        overflow <= 0;
        case (aluop)
            //����ָ��
            `ALUOP_ADD   : begin
               y <= a + b; 
               overflow <= (a[31] == b[31]) & (y[31] != a[31]);
            end
            `ALUOP_ADDU  : begin
                y <= a + b;
            end
            `ALUOP_ADDI  : begin
                y <= a + b;
                overflow <= (a[31] == b[31]) & (y[31] != a[31]);
            end
            `ALUOP_ADDIU : y <= a + b;
            `ALUOP_SUB   : begin 
                y <= a - b;
                overflow <= (a[31]^b[31]) & (y[31]==b[31]);
            end
            `ALUOP_SUBU  : begin 
                y <= a - b;
            end
            `ALUOP_SLT   : y <= $signed(a) < $signed(b);
            `ALUOP_SLTU  : y <= a < b;
            `ALUOP_SLTI  :  begin//y <= a < b;
                case(a[31])
                    1'b1: begin
                        if(b[31] == 1'b1) begin
                            y <= a < b;
                        end
                        else begin
                            y <= 1'b1;
                        end
                    end
                    1'b0: begin
                        if(b[31] == 1'b1) begin
                            y <= 1'b0;
                        end
                        else begin
                            y <= a < b;
                        end
                    end
                endcase
            end
            `ALUOP_SLTIU : y <= a < b;
            `ALUOP_MULT  : temp_aluout_64 <= (a[31]^b[31]==1'b1)? ~(multa * multb) + 1 :  multa * multb; 
            `ALUOP_MULTU : temp_aluout_64 <= a * b;
            `ALUOP_DIV   :begin
                if(div_ready ==1'b0) begin
                    start_div <= `DivStart;
                    signed_div <=1'b1;
                    stall_div <=1'b1;
                end else if (div_ready == 1'b1) begin
                    start_div <= `DivStop;
                    signed_div <=1'b1;
                    stall_div <=1'b0;
                end else begin
                    start_div <= `DivStop;
                    signed_div <=1'b0;
                    stall_div <=1'b0;
                end
            end
            `ALUOP_DIVU :begin
                if(div_ready ==1'b0) begin
                    start_div <= 1'b1;
                    signed_div <=1'b0;
                    stall_div <=1'b1;
                end else if (div_ready == 1'b1) begin
                    start_div <= 1'b0;
                    signed_div <=1'b0;
                    stall_div <=1'b0;
                end else begin
                    start_div <= 1'b0;
                    signed_div <=1'b0;
                    stall_div <=1'b0;
                end
            end
            //�߼�ָ��
            `ALUOP_AND   : y <= a & b;
            `ALUOP_OR    : y <= a | b;
            `ALUOP_NOR   : y <= ~ (a | b);
            `ALUOP_XOR   : y <= a ^ b;
            `ALUOP_ANDI  : y <= a & b;
            `ALUOP_ORI   : y <= a | b;
            `ALUOP_XORI  : y <= a ^ b;
            `ALUOP_LUI   : y <={b[15:0],16'b0};
            
            // ��λָ��
            `ALUOP_SLL   : y <= b << a[4:0];
            `ALUOP_SLLV: y <= b << a[4:0];
            `ALUOP_SRL: y <= b >> a[4:0];
            `ALUOP_SRLV: y <= b >> a[4:0];
            `ALUOP_SRA: y <= $signed(b) >>> a[4:0];
            `ALUOP_SRAV: y <= $signed(b) >>> a[4:0];
            // �����ƶ�ָ��
            `ALUOP_MTHI: temp_aluout_64 <= {a,hilo[31:0]};
            `ALUOP_MTLO: temp_aluout_64 <= {hilo[63:32],a};
            `ALUOP_MFHI: y <= hilo[63:32];
            `ALUOP_MFLO: y <= hilo[31:0];
            `ALUOP_MFC0: y <= cp0_data_o;
            default      : y <= 32'b0;
        endcase
    end
    
    div mydiv(
        .clk(clk),
        .rst(rst),
        .ena(~stall_div),
        .signed_div_i(signed_div), 
        .opdata1_i(a),
        .opdata2_i(b),
        
        .state(state_div),
        .start_i(start_div),
        .annul_i(1'b0),
        .result_o(div_result),
        .ready_o(div_ready)
);
    
endmodule
