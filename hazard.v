`timescale 1ns/1ps
module hazard (
    input  wire regwriteE,regwriteM,regwriteW,
    input  wire memtoRegE,memtoRegM,
    input  wire branchD,jrD,stall_divE,i_stall,d_stall,
    input  wire [4:0]rsD,rtD,rsE,rtE,reg_waddrM,reg_waddrW,reg_waddrE,
    output wire stallF,stallD,stallE,stallM,stallW,longest_stall,
    output wire flushE,
    output wire forwardAD,forwardBD,
    output wire [1 :0] forwardAE, forwardBE,
    // 异常
    input  wire [5 :0] opM,
    input  wire [31:0] excepttypeM,
    input  wire [31:0] cp0_epcM,
    output reg  [31:0] newpcM
);
    
    // data forward  M->E, W->E
    assign forwardAE =  ((rsE != 5'b0) & (rsE == reg_waddrM) & regwriteM) ? 2'b10: // 前推计算结果
                        ((rsE != 5'b0) & (rsE == reg_waddrW) & regwriteW) ? 2'b01: // 前推写回结果
                        2'b00; // 原结果
    assign forwardBE =  ((rtE != 5'b0) & (rtE == reg_waddrM) & regwriteM) ? 2'b10: // 前推计算结果
                        ((rtE != 5'b0) & (rtE == reg_waddrW) & regwriteW) ? 2'b01: // 前推写回结果
                        2'b00; // 原结果 
    
    // 控制冒险产生的写冲突 
    // 0 原结果， 1 写回结果
    assign forwardAD = (rsD != 5'b0) & (rsD == reg_waddrM) & regwriteM;
    assign forwardBD = (rtD != 5'b0) & (rtD == reg_waddrM) & regwriteM;
    
    // 判断 decode 阶段 rs 或 rt 的地址是否是上一个lw 指令要写入的地址rtE；
    wire lwstall,branch_stall,jr_stall; // 指令阻塞：lwstall 取数-使用型数据冒险
    // assign lwstall = ((rsD == rtE) | (rtD == rtE)) & memtoRegE;
    assign lwstall = ((rsD == rtE) | (rtD == rsE)) & memtoRegE;
    assign branch_stall =  (branchD & regwriteE & ((rsD == reg_waddrE)|(rtD == reg_waddrE))) | // 执行阶段阻塞，前面有写入的数据
                            (branchD & memtoRegM & ((rsD == reg_waddrM)|(rtD == reg_waddrM))); // 写回阶段阻塞
    
    assign jr_stall =(jrD & regwriteE & ((rsD == reg_waddrE)|(rtD == reg_waddrE))) | // 执行阶段阻塞，前面有写入的数据
                    (jrD & memtoRegM & ((rsD == reg_waddrM)|(rtD == reg_waddrM))); // 写回阶段阻塞
    assign longest_stall = stall_divE | i_stall | d_stall;

    assign flushE = (lwstall | branch_stall | jr_stall) & ~longest_stall;
    assign stallF = lwstall | branch_stall | jr_stall | longest_stall;
    assign stallD = lwstall | branch_stall | jr_stall | longest_stall;
    assign stallE = longest_stall; // i_stall | 取指阶段是否需要不阻塞E_M_W
    assign stallM = i_stall | d_stall; 
    assign stallW = i_stall | d_stall;    

    always @(*) begin
        if(excepttypeM != 32'b0) begin
            case (excepttypeM)
                32'h00000001: begin
                    newpcM <= 32'hBFC00380;
                end
                32'h00000004: begin
                    newpcM <= 32'hBFC00380;
                end
                32'h00000005: begin
                    newpcM <= 32'hBFC00380;
                end
                32'h00000008: begin
                    newpcM <= 32'hBFC00380;
                end
                32'h00000009: begin
                    newpcM <= 32'hBFC00380;
                end
                32'h0000000a: begin
                    newpcM <= 32'hBFC00380;
                end
                32'h0000000c: begin
                    newpcM <= 32'hBFC00380;
                end
                32'h0000000d: begin
                    newpcM <= 32'hBFC00380;
                end
                32'h0000000e: begin
                    newpcM <= cp0_epcM;
                end
                default : ;
            endcase
        end
    end

    // TODO 代码优化
    // always @(*) begin
    //     if(excepttypeM != 32'b0) begin
    //         case (excepttypeM)
    //             32'h00000001, 32'h00000004, 32'h00000005, 32'h00000008, 
    //             32'h00000009, 32'h0000000a, 32'h0000000c, 32'h0000000d:
    //                 newpcM <= 32'hBFC00380;
    //             32'h0000000e: newpcM <= cp0_epcM;
    //             default : newpcM <= 32'h00000000; // 或者当前pc值
    //         endcase
    //     end
    // end
endmodule