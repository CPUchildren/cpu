`timescale 1ns/1ps
`include "defines.vh"
module main_dec(
    input wire clk,rst,flushE,stallE,
    input wire [31:0]instrD,
    output wire regwriteW,regdstE,alusrcAE,alusrcBE,branchD,memWriteM,memtoRegW,
    output wire regwriteE,regwriteM,memtoRegE,memtoRegM,hilowriteM,
    output wire jumpD,balD,balE,balW,jalD,jalE,jalW,jrD,jrE,jrW
);
    // Decoder
    wire [5:0]op;
    wire [5:0]funct;
    wire [4:0]rt;
    reg [11:0]signsD;
    wire [11:0]signsE,signsW,signsM;
    wire ena;

    assign op = instrD[31:26];
    assign funct = instrD[5:0];
    assign rt = instrD[20:16];
    assign regwriteW = signsW[6];
    assign regwriteE = signsE[6];
    assign regwriteM = signsM[6];
    assign regdstE = signsE[5];
    assign alusrcAE = signsE[7];
    assign alusrcBE = signsE[4];
    assign branchD = signsD[3];
    assign memWriteM = signsM[2];
    assign memtoRegW = signsW[1];
    assign memtoRegE = signsE[1];
    assign memtoRegM = signsM[1];
    assign jumpD = signsD[0];
    assign hilowriteM = signsM[11];
    assign balD=signsD[10];
    assign balE=signsE[10];
    assign balW=signsW[10];
    assign jalD=signsD[8];
    assign jalE=signsE[8];
    assign jalW=signsW[8];
    assign jrD=signsD[9];
    assign jrE=signsE[9];
    assign jrW=signsW[9];


    assign ena = 1'b1;

    // signsD = {11hilowrite,10bal,9jr,8jal,7alusrcA,6regwrite,5regdst,,4alusrcB,3branch,2memWrite,1memtoReg,0jump}
    always @(*) begin
        case(op)
            `OP_R_TYPE:
                case (funct)
                    //移位指令
                    `FUN_SLL   : signsD <= 12'b000011100000 ;
                    `FUN_SRL   : signsD <= 12'b000011100000 ;
                    `FUN_SRA   : signsD <= 12'b000011100000 ;
                    //逻辑和算术指�? default
                    // 分支跳转
                    `FUN_JR    : signsD <= 12'b001000000001;
                    `FUN_JALR  : signsD <= 12'b001001100000;
                    //数据移动指令
                    `FUN_MTHI  : signsD <= 12'b100000000000;
                    `FUN_MTLO  : signsD <= 12'b100000000000;
                    //�?化，r-type默认控制信号
                    default: signsD <= 12'b000001100000;
                endcase
            // 访存指令
            `OP_LB    : signsD <= 12'b000001010010;
            `OP_LBU   : signsD <= 12'b000001010010;
            `OP_LH    : signsD <= 12'b000001010010;
            `OP_LHU   : signsD <= 12'b000001010010;
            `OP_LW    : signsD <= 12'b000001010010; // lw
            `OP_SB    : signsD <= 12'b000000010110;
            `OP_SH    : signsD <= 12'b000000010110;
            `OP_SW    : signsD <= 12'b000000010110; // sw
            //arithmetic type
            `OP_ADDI  : signsD <= 12'b000001010000; // addi
            `OP_ADDIU : signsD <= 12'b000001010000; // addiu     //alusrcA应该�?1
            `OP_SLTI  : signsD <= 12'b000001010000;// slti
            `OP_SLTIU : signsD <= 12'b000001010000; // sltiu
            //logical type
            `OP_ANDI  : signsD <= 12'b000001010000; // andi
            `OP_ORI   : signsD <= 12'b000001010000; // ori
            `OP_XORI  : signsD <= 12'b000001010000; // xori
            `OP_LUI   : signsD <= 12'b000001010000; // lui
            
            // 分支跳转指令
            // alusrcA,regwrite,regdst,alusrcB,branch,memWrite,memtoReg,jump
            // TODO 控制信号有待确认
            `OP_BEQ   : signsD <= 12'b000000001000; // BEQ
            `OP_BNE   : signsD <= 12'b000000001000; // BNE
            `OP_BGTZ  : signsD <= 12'b000000001000; // BGTZ
            `OP_BLEZ  : signsD <= 12'b000000001000; // BLEZ  
            `OP_SPEC_B:     // BGEZ,BLTZ,BGEZAL,BLTZAL
                case(rt)
                    `RT_BGEZ : signsD  <= 12'b000000001000;
                    `RT_BLTZ : signsD  <= 12'b000000001000;
                    `RT_BGEZAL: signsD <= 12'b010001001000;
                    `RT_BLTZAL: signsD <= 12'b010001001000;
                    default:;
                endcase
            `OP_J     : signsD <= 12'b000000000001; // J     
            `OP_JAL   : signsD <= 12'b000101000000; 

            default:;
        endcase
    end
   
    // Execute
    flopenrc #(12) dff1E(clk,rst,flushE,~stallE,signsD,signsE);
    // Mem
    flopenr #(12) dff1M(clk,rst,ena,signsE,signsM);
    // Write
    flopenr #(12) dff1W(clk,rst,ena,signsM,signsW);    
    
endmodule
