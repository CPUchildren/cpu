`timescale 1ns / 1ps
`include "defines.vh"
module datapath (
    input wire clk,rst,
    input wire [31:0]instrF,data_sram_rdataM,

    output wire [3:0] data_sram_wenM,
    output wire [31:0]pc_now,data_sram_waddr,
    output wire [31:0]data_sram_wdataM
    
);

// ====================================== 变量定义区，every part ======================================
wire clear,ena;
wire [63:0]hilo;
// F
wire stallF;
wire [31:0]pc_plus4F,pc_next,pc_next_jump;
// D
wire stallD,flushD,forwardAD,forwardBD;
wire pcsrcD,equalD,branchD,jumpD,jrD;
wire [4:0]rtD,rdD,rsD,saD;
wire [31:0]pc_nowD,pc_plus4D,pc_branchD,rd1D,rd2D,rd1D_branch,rd2D_branch;
wire [31:0]instrD_sl2,sign_immD,sign_immD_sl2;
// E
wire flushE,regdstE,alusrcAE,alusrcBE,regwriteE,memtoRegE;
wire [1:0]forwardAE,forwardBE;
wire [4:0]rtE,rdE,rsE,saE,rd1_saE,reg_waddrE;
wire [7:0]alucontrolE;
wire [31:0]instrE,rd1E,rd2E,srcB,sign_immE;
wire [31:0]pc_nowE,alu_resE,aluout_64E,sel_rd1E,sel_rd2E,sel_rd2M;
// M
wire memtoRegM,regwriteM,memWriteM;
wire [4:0]reg_waddrM;
wire [31:0]instrM,pc_nowM,alu_resM,aluout_64M;
reg  [31:0]read_dataM;
// W
wire memtoRegW,regwriteW;
wire [4:0]reg_waddrW;
wire [31:0]pc_nowW, alu_resW, wd3W, data_sram_rdataW;

assign clear = 1'b0;
assign ena = 1'b1;
assign flushD = pcsrcD | jumpD;

// ====================================== Fetch ======================================
mux2 mux2_branch(
    .a(pc_plus4F),
    .b(pc_branchD),
    .sel(pcsrcD),
    .y(pc_next)
    ); // 注意，这里是PC_next是沿用的pc_plus4F

mux2 mux2_jump(
    .a(pc_next),
    .b({pc_plus4D[31:28],instrD_sl2[27:0]}), // 注意，这里是D阶段执行的pc_plus4D
    .sel(jumpD),
    .y(pc_next_jump)
);

pc pc(
    .clk(clk),
    .rst(rst),
    .ena(~stallF),
    .din(pc_next_jump),
    .dout(pc_now)
);

adder adder(
    .a(pc_now),
    .b(32'd4),
    .y(pc_plus4F)
);

// ====================================== Decoder ======================================
// TODO 数据冒险分析（这里要不要flushD都没问题，因为跳转指令后面都是一个nop，所以没关系）
flopenrc DFF_instrD(clk,rst,flushD,~stallD,instrF,instrD);
flopenrc DFF_pc_plus4D(clk,rst,clear,~stallD,pc_plus4F,pc_plus4D);

main_dec main_dec(
    .clk(clk),
    .rst(rst),
    .op(instrD[31:26]),
    .funct(instrD[5:0]),
    .rt(instrD[20:16]),
    
    .regwriteW(regwriteW),
    .regdstE(regdstE),
    .alusrcAE(alusrcAE),
    .alusrcBE(alusrcBE),
    .branchD(branchD),
    .memWriteM(memWriteM),
    .memtoRegW(memtoRegW),
    .jumpD(jumpD),
    .regwriteE(regwriteE),
    .regwriteM(regwriteM),
    .memtoRegE(memtoRegE),
    .memtoRegM(memtoRegM),
    .hilowriteM(hilowriteM),
    .jrD(jrD)
);

alu_dec alu_decoder(
    .clk(clk), 
    .rst(rst),
    .op(instrD[31:26]),
    .funct(instrD[5:0]),

    .aluopE(alucontrolE)
);

assign rsD = instrD[25:21];
assign rtD = instrD[20:16];
assign rdD = instrD[15:11];
assign saD = instrD[10:6];

regfile regfile(
	.clk(clk),
	.we3(regwriteW),
	.ra1(instrD[25:21]), 
    .ra2(instrD[20:16]),
    .wa3(reg_waddrW), // 前in后out
	.wd3(wd3W), 
	.rd1(rd1D),
    .rd2(rd2D)
);

// jump指令拓展
sl2 sl2_instr(
    .a(instrD),
    .y(instrD_sl2)
);

signext sign_extend(
    .a(instrD[15:0]), 
    .type(instrD[29:28]),

    .y(sign_immD) 
);

sl2 sl2_signImm(
    .a(sign_immD),
    .y(sign_immD_sl2)
);

adder adder_branch(
    .a(sign_immD_sl2),
    .b(pc_plus4D),
    .y(pc_branchD)
);

// ******************* 控制冒险 *****************
// 在 regfile 输出后添加一个判断相等的模块，即可提前判断 beq，以将分支指令提前到Decode阶段（预测）
mux2 #(32) mux2_forwardAD(rd1D,alu_resM,forwardAD,rd1D_branch);
mux2 #(32) mux2_forwardBD(rd2D,alu_resM,forwardBD,rd2D_branch);
// assign equalD = (rd1D_branch == rd2D_branch);
assign equalD = (rd1D_branch == rd2D_branch) ? 1:0;
assign pcsrcD = equalD & branchD;

// ====================================== Execute ======================================

flopenrc #(32) DFF_rd1E(clk,rst,flushE,ena,rd1D,rd1E);
flopenrc #(32) DFF_rd2E(clk,rst,flushE,ena,rd2D,rd2E);
flopenrc #(32) DFF_sign_immE(clk,rst,flushE,ena,sign_immD,sign_immE);
flopenrc #(5) DFF_rtE(clk,rst,flushE,ena,rtD,rtE);
flopenrc #(5) DFF_rdE(clk,rst,flushE,ena,rdD,rdE);
flopenrc #(5) DFF_rsE(clk,rst,flushE,ena,rsD,rsE);
flopenrc #(5) DFF_saE(clk,rst,flushE,ena,saD,saE);
flopenrc DFF_instrE(clk,rst,flushD,ena,instrD,instrE);

mux2 #(5) mux2_regDst(.a(rtE),.b(rdE),.sel(regdstE),.y(reg_waddrE));

mux2 #(32) mux2_alusrcAE(.a(rd1E),.b({{27{1'b0}},saE}),.sel(alusrcAE),.y(rd1_saE));

// ******************* 数据冒险 *****************
// 00原结果，01写回结果_W， 10计算结果_M
mux3 #(32) mux3_forwardAE(rd1_saE,wd3W,alu_resM,forwardAE,sel_rd1E);
mux3 #(32) mux3_forwardBE(rd2E,wd3W,alu_resM,forwardBE,sel_rd2E);
mux2 mux2_aluSrc(.a(sel_rd2E),.b(sign_immE),.sel(alusrcBE),.y(srcB));

alu alu(
    .a(sel_rd1E),
    .b(srcB),
    .aluop(alucontrolE),
    .hilo(hilo),

    .y(alu_resE),
    .aluout_64(aluout_64E),
    .overflow(),
    .zero() // wire zero ==> branch跳转控制（已经升级到*控制冒险*）
);

// ====================================== Memory ======================================
flopenrc DFF_alu_resM(clk,rst,clear,ena,alu_resE,alu_resM);
flopenrc DFF_sel_rd2EM(clk,rst,clear,ena,sel_rd2E,sel_rd2M);
flopenrc #(5) DFF_reg_waddrM(clk,rst,clear,ena,reg_waddrE,reg_waddrM);
flopenrc DFF_instrM(clk,rst,clear,ena,instrE,instrM);
flopenrc #(64) DFF_aluout_64M(clk,rst,clear,ena,aluout_64E,aluout_64M);

// M阶段写回hilo
hilo_reg hilo_reg(
	.clk(clk),.rst(rst),.we(hilowriteM),
	.hilo_i(aluout_64M),
	// .hilo_res(hilo_res)
	.hilo(hilo)  // hilo current data
);

assign data_sram_waddr = alu_resM;

// 访存设置
lsmem lsmen(
    .opM(instrM[31:26]),
    .sel_rd2M(sel_rd2M),
    .data_sram_rdataM(data_sram_rdataM),

    .data_sram_wenM(data_sram_wenM),
    .data_sram_wdataM(data_sram_wdataM),
    .read_dataM(read_dataM)
);

// ====================================== WriteBack ======================================
flopenrc DFF_alu_resW(clk,rst,clear,ena,alu_resM,alu_resW);
flopenrc DFF_data_sram_rdataW(clk,rst,clear,ena,read_dataM,data_sram_rdataW);
flopenrc #(5) DFF_reg_waddrW(clk,rst,clear,ena,reg_waddrM,reg_waddrW);

mux2 mux2_memtoReg(.a(alu_resW),.b(data_sram_rdataW),.sel(memtoRegW),.y(wd3W));

// ******************* 冒险信号总控制 *****************
hazard hazard(
    regwriteE,regwriteM,regwriteW,memtoRegE,memtoRegM,branchD,jrD,
    rsD,rtD,rsE,rtE,reg_waddrM,reg_waddrW,reg_waddrE,
    stallF,stallD,flushE,forwardAD,forwardBD,
    forwardAE, forwardBE
);

endmodule