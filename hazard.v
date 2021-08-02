`timescale 1ns/1ps
module hazard (
    input wire regwriteE,regwriteM,regwriteW,
    input wire memtoRegE,memtoRegM,
    input wire pcsrcD,jumpD,jalD,branchD,jrD,
    input wire stall_divE,i_stall,d_stall,
    input wire [4:0]rsD,rtD,rsE,rtE,
    input wire [4:0]reg_waddrM,reg_waddrW,reg_waddrE,
    
    output wire forwardAD,forwardBD,
    output wire [1:0] forwardAE, forwardBE,
    output wire stallF,stallD,stallE,stallM,stallW,longest_stall,
    output wire flushD,flushE,flushM,flushW,
    

    // �쳣
    input wire [5:0] opM,
    input wire except_logicM,
    input wire [31:0] excepttypeM,
    input wire [31:0] cp0_epcM,
    output reg [31:0] newpcM
);
    // ����ǰ��
    // 0 ԭ�����1 д�ؽ��
    assign forwardAD = (rsD != 5'b0) & (rsD == reg_waddrM) & regwriteM;  
    assign forwardBD = (rtD != 5'b0) & (rtD == reg_waddrM) & regwriteM;

    // 10 ǰ�Ƽ�������01 ǰ��д�ؽ����00 ԭ���
    assign forwardAE =  ((rsE != 5'b0) & (rsE == reg_waddrM) & regwriteM) ? 2'b10: 
                        ((rsE != 5'b0) & (rsE == reg_waddrW) & regwriteW) ? 2'b01: 
                        2'b00; 
    assign forwardBE =  ((rtE != 5'b0) & (rtE == reg_waddrM) & regwriteM) ? 2'b10: 
                        ((rtE != 5'b0) & (rtE == reg_waddrW) & regwriteW) ? 2'b01: 
                        2'b00; 

    // ����
    wire lwstall,branch_stall,jr_stall;
    assign lwstall = ((rsD == rtE) | (rtD == rsE)) & memtoRegE;
    assign branch_stall =   (branchD & regwriteE & ((rsD == reg_waddrE)|(rtD == reg_waddrE))) | // ִ�н׶�������ǰ����д�������
                            (branchD & memtoRegM & ((rsD == reg_waddrM)|(rtD == reg_waddrM)));  // д�ؽ׶�����
    assign jr_stall =(jrD & regwriteE & ((rsD == reg_waddrE)|(rtD == reg_waddrE))) | 
                    (jrD & memtoRegM & ((rsD == reg_waddrM)|(rtD == reg_waddrM))); 
    assign longest_stall = stall_divE | i_stall | d_stall;
    assign stallF = longest_stall | lwstall | branch_stall | jr_stall;
    assign stallD = longest_stall | lwstall | branch_stall | jr_stall;
    assign stallE = longest_stall;
    assign stallM = longest_stall; 
    assign stallW = longest_stall;

    assign flushD = except_logicM;
    assign flushE = except_logicM | ((lwstall | branch_stall | jr_stall)  & ~i_stall & ~d_stall);  
    assign flushM = except_logicM;
    assign flushW = except_logicM; // flushW=�쳣ˢ��

    always @(*) begin
        case (excepttypeM)
            32'h00000001,32'h00000004,32'h00000005,32'h00000008,
            32'h00000009,32'h0000000a,32'h0000000c,32'h0000000d: begin
                newpcM <= 32'hBFC00380;
            end
            32'h0000000e: newpcM <= cp0_epcM;
            default     : newpcM <= 32'hBFC00380;
        endcase
    end

    
endmodule
