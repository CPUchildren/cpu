`timescale 1ns/1ps
module hazard (
    input wire pcsrcD,jumpD,jalD,
    input wire regwriteE,regwriteM,regwriteW,memtoRegE,memtoRegM,branchD,jrD,stall_divE,
    input wire [4:0]rsD,rtD,rsE,rtE,reg_waddrM,reg_waddrW,reg_waddrE,
    output wire stallF,stallD,stallE,
    output wire flushD,flushE,flushM,flushW,pc_flushE,
    output wire forwardAD,forwardBD,
    output wire[1:0] forwardAE, forwardBE,

    input wire [5:0] opM,
    input wire [31:0] excepttypeM,
    input wire [31:0] cp0_epcM,
    output reg [31:0] newpcM
);
    // 数据前推
    // 0 原结果，1 写回结果
    assign forwardAD = (rsD != 5'b0) & (rsD == reg_waddrM) & regwriteM;  
    assign forwardBD = (rtD != 5'b0) & (rtD == reg_waddrM) & regwriteM;

    // 10 前推计算结果，01 前推写回结果，00 原结果
    assign forwardAE =  ((rsE != 5'b0) & (rsE == reg_waddrM) & regwriteM) ? 2'b10: 
                        ((rsE != 5'b0) & (rsE == reg_waddrW) & regwriteW) ? 2'b01: 
                        2'b00; 
    assign forwardBE =  ((rtE != 5'b0) & (rtE == reg_waddrM) & regwriteM) ? 2'b10: 
                        ((rtE != 5'b0) & (rtE == reg_waddrW) & regwriteW) ? 2'b01: 
                        2'b00; 

    // 阻塞
    wire lwstall,branch_stall,jr_stall;
    assign lwstall = ((rsD == rtE) | (rtD == rsE)) & memtoRegE;
    assign branch_stall =   (branchD & regwriteE & ((rsD == reg_waddrE)|(rtD == reg_waddrE))) | // 执行阶段阻塞，前面有写入的数据
                            (branchD & memtoRegM & ((rsD == reg_waddrM)|(rtD == reg_waddrM)));  // 写回阶段阻塞
    assign jr_stall =(jrD & regwriteE & ((rsD == reg_waddrE)|(rtD == reg_waddrE))) | 
                    (jrD & memtoRegM & ((rsD == reg_waddrM)|(rtD == reg_waddrM))); 
    assign stallF = lwstall | branch_stall | jr_stall | stall_divE;
    assign stallD = lwstall | branch_stall | jr_stall | stall_divE;
    assign stallE = stall_divE;

    // 刷新
    assign flushD = (|excepttypeM);
    assign flushE = lwstall | branch_stall | jr_stall | (|excepttypeM);
    assign flushM = (|excepttypeM);
    assign pc_flushE = lwstall | branch_stall | jr_stall;
    assign flushW = (|excepttypeM);

    always @(*) begin
        if(excepttypeM != 32'b0) begin
            case (excepttypeM)
                32'h00000001,32'h00000004,32'h00000005,32'h00000008,
                32'h00000009,32'h0000000a,32'h0000000c,32'h0000000d: begin
                    newpcM <= 32'hBFC00380;
                end
                32'h0000000e: newpcM <= cp0_epcM;
                default     : newpcM <= 32'hBFC00380;
            endcase
        end
    end
endmodule
