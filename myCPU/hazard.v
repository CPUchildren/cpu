`timescale 1ns/1ps
module hazard (
    input wire regwriteE,regwriteM,regwriteW,memtoRegE,memtoRegM,branchD,jrD,stall_divE,
    input wire [4:0]rsD,rtD,rsE,rtE,reg_waddrM,reg_waddrW,reg_waddrE,
    output wire stallF,stallD,stallE,flushE,forwardAD,forwardBD,
    output wire[1:0] forwardAE, forwardBE,

    input wire [5:0] opM,
    input wire [31:0] excepttypeM,
    input wire [31:0] cp0_epcM,
    output reg [31:0] newpcM
);
    wire [1:0] forwardhiloE;
    wire forwardcp0E;
    // ????
    assign forwardAE =  ((rsE != 5'b0) & (rsE == reg_waddrM) & regwriteM) ? 2'b10: // ǰ�Ƽ�����
                        ((rsE != 5'b0) & (rsE == reg_waddrW) & regwriteW) ? 2'b01: // ǰ��д�ؽ��
                        2'b00; // ԭ��??
    assign forwardBE =  ((rtE != 5'b0) & (rtE == reg_waddrM) & regwriteM) ? 2'b10: // ǰ�Ƽ�����
                        ((rtE != 5'b0) & (rtE == reg_waddrW) & regwriteW) ? 2'b01: // ǰ��д�ؽ��
                        2'b00; // ԭ��?? 
    
    // assign forwardhiloE=(hilo_weE==2'b00 & (hilo_weM==2'b10 | hilo_weM==2'b01 | hilo_weM==2'b11))?2'b01:
    //                     (hilo_weE==2'b00 & (hilo_weW==2'b10 | hilo_weW==2'b01 | hilo_weW==2'b11))?2'b10:
    //                     2'b00;
    // assign forwardcp0E=((rdE!=0)&(rdE==rdM)&(cp0weM))?1'b1:1'b0;
    // ?????????? 
    // 0 ???? 1 ????
    assign forwardAD = (rsD != 5'b0) & (rsD == reg_waddrM) & regwriteM;
    assign forwardBD = (rtD != 5'b0) & (rtD == reg_waddrM) & regwriteM;
    
    // �ж� decode ��??? rs ?? rt �ĵ�????������???��lw ָ��Ҫд��ĵ�ַrtE??
    wire lwstall,branch_stall,jr_stall; // ָ����???��lwstall ȡ��-ʹ������??ð???
    // assign lwstall = ((rsD == rtE) | (rtD == rtE)) & memtoRegE;
    assign lwstall = ((rsD == rtE) | (rtD == rsE)) & memtoRegE;
    assign branch_stall =   (branchD & regwriteE & ((rsD == reg_waddrE)|(rtD == reg_waddrE))) | // ִ???�׶�������ǰ����д�����???
                            (branchD & memtoRegM & ((rsD == reg_waddrM)|(rtD == reg_waddrM))); // д�ؽ�???��??
    
    assign jr_stall =(jrD & regwriteE & ((rsD == reg_waddrE)|(rtD == reg_waddrE))) | // ִ???�׶�������ǰ����д�����???
                    (jrD & memtoRegM & ((rsD == reg_waddrM)|(rtD == reg_waddrM))); // д�ؽ�???��??

    assign stallF = lwstall | branch_stall | jr_stall | stall_divE;
    assign stallD = lwstall | branch_stall | jr_stall | stall_divE;
    assign flushE = lwstall | branch_stall | jr_stall;
    assign stallE = stall_divE;

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
endmodule