`timescale 1ns/1ps
module hazard (
    input wire regwriteE,regwriteM,regwriteW,memtoRegE,memtoRegM,branchD,jrD,stall_divE,
    input wire [4:0]rsD,rtD,rsE,rtE,reg_waddrM,reg_waddrW,reg_waddrE,
    output wire stallF,stallD,stallE,flushE,forwardAD,forwardBD,
    output wire[1:0] forwardAE, forwardBE
);
    
    // 数据冒险
    assign forwardAE =  ((rsE != 5'b0) & (rsE == reg_waddrM) & regwriteM) ? 2'b10: // 前推计算结果
                        ((rsE != 5'b0) & (rsE == reg_waddrW) & regwriteW) ? 2'b01: // 前推写回结果
                        2'b00; // 原结�?
    assign forwardBE =  ((rtE != 5'b0) & (rtE == reg_waddrM) & regwriteM) ? 2'b10: // 前推计算结果
                        ((rtE != 5'b0) & (rtE == reg_waddrW) & regwriteW) ? 2'b01: // 前推写回结果
                        2'b00; // 原结�? 
    
    // 控制冒险产生的写冲突 
    // 0 原结果， 1 写回结果
    assign forwardAD = (rsD != 5'b0) & (rsD == reg_waddrM) & regwriteM;
    assign forwardBD = (rtD != 5'b0) & (rtD == reg_waddrM) & regwriteM;
    
    // 判断 decode 阶段 rs �? rt 的地�?是否是上�?个lw 指令要写入的地址rtE�?
    wire lwstall,branch_stall,jr_stall; // 指令阻塞：lwstall 取数-使用型数据冒�?
    // assign lwstall = ((rsD == rtE) | (rtD == rtE)) & memtoRegE;
    assign lwstall = ((rsD == rtE) | (rtD == rsE)) & memtoRegE;
    assign branch_stall =   (branchD & regwriteE & ((rsD == reg_waddrE)|(rtD == reg_waddrE))) | // 执行阶段阻塞，前面有写入的数�?
                            (branchD & memtoRegM & ((rsD == reg_waddrM)|(rtD == reg_waddrM))); // 写回阶段阻塞
    
    assign jr_stall =(jrD & regwriteE & ((rsD == reg_waddrE)|(rtD == reg_waddrE))) | // 执行阶段阻塞，前面有写入的数�?
                    (jrD & memtoRegM & ((rsD == reg_waddrM)|(rtD == reg_waddrM))); // 写回阶段阻塞

    assign stallF = lwstall | branch_stall | jr_stall | stall_divE;
    assign stallD = lwstall | branch_stall | jr_stall | stall_divE;
    assign flushE = lwstall | branch_stall | jr_stall;
    assign stallE = stall_divE;
endmodule