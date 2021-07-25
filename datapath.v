`timescale 1ns / 1ps
`include "defines.vh"
module datapath (
    input wire clk,rst,i_stall,d_stall,longest_stall,
    input wire [31:0]instrF,data_sram_rdataM,

    output wire memenD,
    output wire [3:0] data_sram_wenM,
    output wire [31:0]pc_now,data_sram_waddr,
    output wire [31:0]data_sram_wdataM
    
);

// ====================================== 变量定义区，every part ======================================
wire clear,ena;
wire [63:0]hilo,hilo_i;
wire div_ready,start_div,signed_div,stall_divE,hilo_in_signal;

// F
wire stallF;
wire [31:0]pc_plus4F,pc_next,pc_next_jump,pc_next_jr,pc_next_j;
// D
wire stallD,flushD,forwardAD,forwardBD;
wire pcsrcD,equalD,branchD,jumpD,jrD,balD,jalD;
wire [4:0]rtD,rdD,rsD,saD;
wire [31:0]pc_nowD,pc_plus4D,pc_branchD,rd1D,rd2D,rd1D_branch,rd2D_branch;
wire [31:0]instrD,instrD_sl2,sign_immD,sign_immD_sl2;
// E
wire flushE,stallE,regdstE,alusrcAE,alusrcBE,regwriteE,memtoRegE,jrE,balE,jalE;
wire [1:0]forwardAE,forwardBE;
wire [4:0]rtE,rdE,rsE,saE,reg_waddrE;
wire [7:0]alucontrolE;
wire [31:0]instrE,rd1E,rd2E,srcB,sign_immE,pc_plus4E,pc_plus8E,rd1_saE;
wire [31:0]pc_nowE,alu_resE,sel_rd1E,sel_rd2E,alu_resE_real;
wire [63:0]div_result,aluout_64E;
// M
wire stallM,memtoRegM,regwriteM,memWriteM;
wire [4:0]reg_waddrM;
wire [31:0]instrM,pc_nowM,alu_resM,read_dataM,sel_rd2M;
wire [63:0]div_resultM,aluout_64M;
// W
wire stallW,memtoRegW,regwriteW,balW,jalW;
wire [4:0]reg_waddrW;
wire [31:0]pc_nowW, alu_resW, wd3W, data_sram_rdataW;

assign clear = 1'b0;
assign ena = 1'b1;
assign flushD = pcsrcD | jumpD | jalD | jrD;

// ====================================== Fetch ======================================
mux2 mux2_jump(
    .a(pc_next_jump),
    .b(pc_next_jr), // 选择是jr还是单纯jump的PC
    .sel(jrD),
    .y(pc_next_j)
);
mux3 mux3_branch(
    .d0(pc_plus4F),
    .d1(pc_branchD),
    .d2(pc_next_j),
    .sel({jumpD|jalD|jrD,pcsrcD}),
    .y(pc_next)
    ); // 三选一，正常PC，分支PC，跳转PC
pc pc(
    .clk(clk),
    .rst(rst),
    .ena(~stallF),
    .din(pc_next),
    .dout(pc_now)
);

adder adder(
    .a(pc_now),
    .b(32'd4),
    .y(pc_plus4F)
);

// ====================================== Decoder ======================================
// 延迟槽继续执行，不清空
flopenrc DFF_instrD   (clk,rst,clear,~stallD,instrF,instrD);
flopenrc DFF_pc_nowD  (clk,rst,clear,~stallD,pc_now,pc_nowD);
flopenrc DFF_pc_plus4D(clk,rst,clear,~stallD,pc_plus4F,pc_plus4D);


main_dec main_dec(
    .clk(clk),
    .rst(rst),
    .flushE(flushE),
    .instrD(instrD),
    
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
    .balD(balD),
    .balE(balE),
    .balW(balW),
    .jalD(jalD),
    .jalE(jalE),
    .jalW(jalW),
    .jrD(jrD),
    .jrE(jrE),
    .memenD(memenD)
);

alu_dec alu_decoder(
    .clk(clk), 
    .rst(rst),
    .instrD(instrD),
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
// 跳转PC
assign pc_next_jump={pc_plus4D[31:28],instrD_sl2[27:0]};
assign pc_next_jr=rd1D;

// ******************* 控制冒险 *****************
// 在 regfile 输出后添加一个判断相等的模块，即可提前判断 beq，以将分支指令提前到Decode阶段（预测）
mux2 #(32) mux2_forwardAD(rd1D,alu_resM,forwardAD,rd1D_branch);
mux2 #(32) mux2_forwardBD(rd2D,alu_resM,forwardBD,rd2D_branch);

eqcmp pc_predict(
    .a(rd1D_branch),
    .b(rd2D_branch),
    .op(instrD[31:26]),
    .rt(rtD),
    .y(equalD)
);
assign pcsrcD = equalD & (branchD|balD);

// ====================================== Execute ======================================
flopenrc #(32) DFF_rd1E     (clk,rst,flushE,~stallE,rd1D,rd1E);
flopenrc #(32) DFF_rd2E     (clk,rst,flushE,~stallE,rd2D,rd2E);
flopenrc #(32) DFF_sign_immE(clk,rst,flushE,~stallE,sign_immD,sign_immE);
flopenrc #(5) DFF_rtE       (clk,rst,flushE,~stallE,rtD,rtE);
flopenrc #(5) DFF_rdE       (clk,rst,flushE,~stallE,rdD,rdE);
flopenrc #(5) DFF_rsE       (clk,rst,flushE,~stallE,rsD,rsE);
flopenrc #(5) DFF_saE       (clk,rst,flushE,~stallE,saD,saE);
flopenrc DFF_instrE         (clk,rst,flushE,~stallE,instrD,instrE);
flopenrc DFF_pc_nowE        (clk,rst,flushE,~stallE,pc_nowD,pc_nowE);
flopenrc DFF_pc_plus4E      (clk,rst,flushE,~stallE,pc_plus4D,pc_plus4E);

// link指令对寄存器的选择
mux3 #(5) mux3_regDst(
    .d0(rtE),
    .d1(rdE),
    .d2(5'b11111),
    .sel({balE|jalE,regdstE}),
    .y(reg_waddrE)
    );
mux2 #(32) mux2_alusrcAE(
    .a(rd1E),
    .b({{27{1'b0}},saE}),
    .sel(alusrcAE),
    .y(rd1_saE)
    );
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
    .div_ready(div_ready), 
    
    .start_div(start_div),
    .signed_div(signed_div),
    .stall_div(stall_divE),
    .y(alu_resE),
    .aluout_64(aluout_64E),
    .overflow(),
    .zero() // wire zero ==> branch跳转控制（已经升级到*控制冒险*）
);

adder pc_8(
    .a(pc_plus4E),
    .b(32'h4),
    .y(pc_plus8E)
);

// link指令需要对alu_resE多进行一次选择再向后传
mux2 alu_pc8(
    .a(alu_resE),
    .b(pc_plus8E),
    .sel((balE | jalE) | jrE),
    .y(alu_resE_real)
);

// TODO 为啥div要放在datapath里面
assign hilo_in_signal=((alucontrolE ==`ALUOP_DIV) | (alucontrolE ==`ALUOP_DIVU))? 1:0;
mux2 #(64) mux2_hiloin(.a(aluout_64M),.b(div_resultM),.sel(hilo_in_signal),.y(hilo_i));

// 除法
div mydiv(
	.clk(clk),
	.rst(rst),
	.signed_div_i(signed_div), 
	.opdata1_i(sel_rd1E),
	.opdata2_i(srcB),
	.start_i(start_div),
	.annul_i(1'b0),
	.result_o(div_result),
	.ready_o(div_ready)
);

// ====================================== Memory ======================================
flopenrc DFF_alu_resM         (clk,rst,clear,~stallM,alu_resE_real,alu_resM);
flopenrc DFF_sel_rd2M         (clk,rst,clear,~stallM,sel_rd2E,sel_rd2M);
flopenrc #(5) DFF_reg_waddrM  (clk,rst,clear,~stallM,reg_waddrE,reg_waddrM);
flopenrc DFF_instrM           (clk,rst,clear,~stallM,instrE,instrM);
flopenrc #(64) DFF_aluout_64M (clk,rst,clear,~stallM,aluout_64E,aluout_64M);
flopenrc DFF_pc_nowM          (clk,rst,clear,~stallM,pc_nowE,pc_nowM);

// ******************* wys：数据移动相关指令 *****************
// M阶段写回hilo
hilo_reg hilo_reg(
	.clk(clk),.rst(rst),.we(hilowriteM),
	.hilo_i(hilo_i),
	// .hilo_res(hilo_res)
	.hilo(hilo)  // hilo current data
    );

assign data_sram_waddr = alu_resM;

// 访存设置
lsmem lsmen(
    .opM(instrM[31:26]),
    .sel_rd2M(sel_rd2M), // writedata_4B
    .alu_resM(alu_resM),
    .data_sram_rdataM(data_sram_rdataM),

    .data_sram_wenM(data_sram_wenM),
    .data_sram_wdataM(data_sram_wdataM),
    .read_dataM(read_dataM)
);

// ====================================== WriteBack ======================================
flopenrc DFF_alu_resW         (clk,rst,clear,~stallW,alu_resM,alu_resW);
flopenrc DFF_data_sram_rdataW (clk,rst,clear,~stallW,read_dataM,data_sram_rdataW);
flopenrc #(5) DFF_reg_waddrW  (clk,rst,clear,~stallW,reg_waddrM,reg_waddrW);
flopenrc DFF_pc_nowW          (clk,rst,clear,~stallW,pc_nowM,pc_nowW);


mux2 mux2_memtoReg(.a(alu_resW),.b(data_sram_rdataW),.sel(memtoRegW),.y(wd3W));

// ******************* 冒险信号总控制 *****************
hazard hazard (
    regwriteE,regwriteM,regwriteW,
    memtoRegE,memtoRegM,
    branchD,jrD,
    stall_divE,i_stall,d_stall,
    rsD,rtD,rsE,rtE,reg_waddrM,reg_waddrW,reg_waddrE,

    stallF,stallD,stallE,stallM,stallW,longest_stall,
    flushE,
    forwardAD,forwardBD,
    forwardAE, forwardBE
);

endmodule