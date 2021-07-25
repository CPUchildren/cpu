`timescale 1ns/1ps
module hazard (
    input  wire regwriteE,regwriteM,regwriteW,
    input  wire memtoRegE,memtoRegM,
    input  wire branchD,jrD,
    input  wire stall_divE,i_stall,d_stall,
    input  wire [4:0]rsD,rtD,rsE,rtE,reg_waddrM,reg_waddrW,reg_waddrE,

    output wire stallF,stallD,stallE,stallM,stallW,longest_stall,
    output wire flushE,
    output wire forwardAD,forwardBD,
    output wire[1:0] forwardAE, forwardBE
);
    
    // ����ð��
    assign forwardAE =  ((rsE != 5'b0) & (rsE == reg_waddrM) & regwriteM) ? 2'b10: // ǰ�Ƽ�����
                        ((rsE != 5'b0) & (rsE == reg_waddrW) & regwriteW) ? 2'b01: // ǰ��д�ؽ��
                        2'b00; // ԭ���
    assign forwardBE =  ((rtE != 5'b0) & (rtE == reg_waddrM) & regwriteM) ? 2'b10: // ǰ�Ƽ�����
                        ((rtE != 5'b0) & (rtE == reg_waddrW) & regwriteW) ? 2'b01: // ǰ��д�ؽ��
                        2'b00; // ԭ��� 
    
    // ����ð�ղ�����д��ͻ 
    // 0 ԭ����� 1 д�ؽ��
    assign forwardAD = (rsD != 5'b0) & (rsD == reg_waddrM) & regwriteM;
    assign forwardBD = (rtD != 5'b0) & (rtD == reg_waddrM) & regwriteM;
    
    // �ж� decode �׶� rs �� rt �ĵ�ַ�Ƿ�����һ��lw ָ��Ҫд��ĵ�ַrtE��
    wire lwstall,branch_stall,jr_stall; // ָ��������lwstall ȡ��-ʹ��������ð��
    // assign lwstall = ((rsD == rtE) | (rtD == rtE)) & memtoRegE;
    assign lwstall = ((rsD == rtE) | (rtD == rsE)) & memtoRegE;
    assign branch_stall =   (branchD & regwriteE & ((rsD == reg_waddrE)|(rtD == reg_waddrE))) | // ִ�н׶�������ǰ����д�������
                            (branchD & memtoRegM & ((rsD == reg_waddrM)|(rtD == reg_waddrM))); // д�ؽ׶�����
    
    assign jr_stall =(jrD & regwriteE & ((rsD == reg_waddrE)|(rtD == reg_waddrE))) | // ִ�н׶�������ǰ����д�������
                    (jrD & memtoRegM & ((rsD == reg_waddrM)|(rtD == reg_waddrM))); // д�ؽ׶�����

    assign flushE = lwstall | branch_stall | jr_stall;
    assign stallF = lwstall | branch_stall | jr_stall | stall_divE | i_stall | d_stall;
    assign stallD = lwstall | branch_stall | jr_stall | stall_divE | i_stall | d_stall;
    assign stallE = stall_divE | i_stall | d_stall;
    assign stallM = i_stall | d_stall;
    assign stallW = i_stall | d_stall;
    assign longest_stall = lwstall | branch_stall | jr_stall | stall_divE;
endmodule