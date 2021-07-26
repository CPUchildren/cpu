`timescale 1ns / 1ps
`include "defines.vh"
module datapath (
    input wire clk,rst,
    input wire [31:0]instrF,data_sram_rdataM,

    output wire [3:0] data_sram_wenM,
    output wire [31:0]pc_now,data_sram_waddr,
    output wire [31:0]data_sram_wdataM
    
);
// new
// ====================================== ????????????every part ======================================
wire clear,ena;
wire [63:0]hilo;   // hilo_i;
//wire div_ready,start_div,signed_div,hilo_in_signal;
//wire [1:0] state_div;
// F
wire stallF;
wire [31:0]pc_plus4F,pc_next,pc_next_jump,pc_next_jr,pc_next_j,pc_next_bj;
wire [7:0] exceptF;
// D
wire syscallD,breakD,eretD;
wire stallD,flushD,forwardAD,forwardBD;
wire pcsrcD,equalD,branchD,jumpD,jrD,balD,jalD;
wire [4:0]rtD,rdD,rsD,saD;
wire [31:0]pc_nowD,pc_plus4D,pc_branchD,rd1D,rd2D,rd1D_branch,rd2D_branch,newpc;
wire [31:0]instrD,instrD_sl2,sign_immD,sign_immD_sl2;
wire [7:0] exceptD;
wire invalidD, is_in_delayslotD;
// E
wire flushE,stallE,regdstE,alusrcAE,alusrcBE,regwriteE,memtoRegE,jrE,balE,jalE,stall_divE;
wire [1:0]forwardAE,forwardBE;
wire [4:0]rtE,rdE,rsE,saE,reg_waddrE;
wire [7:0]alucontrolE;
wire [31:0]instrE,rd1E,rd2E,srcB,sign_immE,pc_plus4E,pc_plus8E,rd1_saE;
wire [31:0]pc_nowE,alu_resE,sel_rd1E,sel_rd2E,alu_resE_real,cp0_data_oE;
wire [63:0]div_result,aluout_64E;
wire [7:0] exceptE;
wire overflow, is_in_delayslotE;
// M
wire memtoRegM,regwriteM,memWriteM;
wire [4:0]reg_waddrM;
wire [31:0]instrM,pc_nowM,alu_resM,read_dataM,sel_rd2M,rd2M;
wire [63:0]div_resultM,aluout_64M;
wire [31:0]if_addr;
wire [7:0] exceptM;
wire adelM,adesM;
wire [31:0] newpcM;
wire [31:0] excepttypeM;
wire [31:0] bad_addr;
wire is_in_delayslotM;
wire [4:0]rdM;
// W
wire memtoRegW,regwriteW,balW,jalW,hilowriteM,cp0writeM;
wire [4:0]reg_waddrW;
wire [31:0]pc_nowW, alu_resW, wd3W, data_sram_rdataW;

//hazard
wire[`RegBus] data_o;
wire[`RegBus] count_o;
wire[`RegBus] compare_o;
wire[`RegBus] status_o;
wire[`RegBus] cause_o;
wire[`RegBus] epc_o;
wire[`RegBus] config_o;
wire[`RegBus] prid_o;
wire[`RegBus] badvaddr;
wire timer_int_o;

assign clear = 1'b0;
assign ena = 1'b1;
assign flushD = pcsrcD | jumpD | jalD | jrD;

// ====================================== Fetch ======================================
mux2 mux2_jump(
    .a(pc_next_jump),
    .b(pc_next_jr), // ?????jr???????jump??PC
    .sel(jrD),
    .y(pc_next_j)
);
mux3 mux3_branch(
    .d0(pc_plus4F),
    .d1(pc_branchD),
    .d2(pc_next_j),
    .sel({jumpD|jalD|jrD,pcsrcD}),
    .y(pc_next_bj)
    ); // ??????????PC?????PC?????PC
mux2 mux2_next(
    .a(pc_next_bj),
    .b(newpcM), // ?????jr???????jump??PC
    .sel(|exceptM),
    .y(pc_next)
);

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

// 异常
assign exceptF = (pc_now[1:0] == 2'b00) ? 8'b00000000 : 8'b10000000;

// ====================================== Decoder ======================================
// ?????????У??????
flopenrc DFF_instrD   (clk,rst,clear|(|exceptM),~stallD,instrF,instrD);
flopenrc DFF_pc_nowD  (clk,rst,clear|(|exceptM),~stallD,pc_now,pc_nowD);
flopenrc DFF_pc_plus4D(clk,rst,clear|(|exceptM),~stallD,pc_plus4F,pc_plus4D);
flopenrc #(8) DFF_exceptD(clk,rst,clear|(|exceptM),~stallD,exceptF,exceptD);


main_dec main_dec(
    .clk(clk),
    .rst(rst),
    .flushE(flushE),
    .stallE(stallE),
    .instrD(instrD),
    .exceptM(exceptM),
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
    .cp0writeM(cp0writeM),
    .balD(balD),
    .balE(balE),
    .balW(balW),
    .jalD(jalD),
    .jalE(jalE),
    .jalW(jalW),
    .jrD(jrD),
    .jrE(jrE),
    .invalid(invalidD)
);

alu_dec alu_decoder(
    .clk(clk), 
    .rst(rst),
    .flushE(flushE),
    .stallE(stallE),
    .instrD(instrD),
    .exceptM(exceptM),
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
    .wa3(reg_waddrW), // ?in??out
	.wd3(wd3W), 
	.rd1(rd1D),
    .rd2(rd2D)
);

// jump??????
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
// ???PC
assign pc_next_jump={pc_plus4D[31:28],instrD_sl2[27:0]};
assign pc_next_jr=rd1D_branch;

// 异常
assign syscallD = (instrD[31:26] == 6'b000000 && instrD[5:0] == 6'b001100);
assign breakD = (instrD[31:26] == 6'b000000 && instrD[5:0] == 6'b001101);
assign eretD = (instrD == 32'b01000010000000000000000000011000);
                            
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

assign is_in_delayslotD = (jumpD|jrD|jalD|branchD);

// ====================================== Execute ======================================
flopenrc #(32) DFF_rd1E     (clk,rst,flushE|(|exceptM),~stallE,rd1D,rd1E);
flopenrc #(32) DFF_rd2E     (clk,rst,flushE|(|exceptM),~stallE,rd2D,rd2E);
flopenrc #(32) DFF_sign_immE(clk,rst,flushE|(|exceptM),~stallE,sign_immD,sign_immE);
flopenrc #(5) DFF_rtE       (clk,rst,flushE|(|exceptM),~stallE,rtD,rtE);
flopenrc #(5) DFF_rdE       (clk,rst,flushE|(|exceptM),~stallE,rdD,rdE);
flopenrc #(5) DFF_rsE       (clk,rst,flushE|(|exceptM),~stallE,rsD,rsE);
flopenrc #(5) DFF_saE       (clk,rst,flushE|(|exceptM),~stallE,saD,saE);
flopenrc DFF_instrE         (clk,rst,flushE|(|exceptM),~stallE,instrD,instrE);
flopenrc DFF_pc_nowE        (clk,rst,flushE|(|exceptM),~stallE,pc_nowD,pc_nowE);
flopenrc DFF_pc_plus4E      (clk,rst,flushE|(|exceptM),~stallE,pc_plus4D,pc_plus4E);
flopenrc #(1) DFF_is_in_delayslotE(clk,rst,flushE&(|exceptM),~stallE,is_in_delayslotD,is_in_delayslotE);

// judge except instr
flopenrc #(8) DFF_exceptE(clk,rst,flushE&(|exceptM),ena,{exceptD[7],syscallD,breakD,eretD,invalidD,exceptD[2:0]},exceptE);

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
// ******************* ??????? *****************
// 00??????01д????_W?? 10??????_M
mux3 #(32) mux3_forwardAE(rd1_saE,wd3W,alu_resM,forwardAE,sel_rd1E);
mux3 #(32) mux3_forwardBE(rd2E,wd3W,alu_resM,forwardBE,sel_rd2E);
mux2 mux2_aluSrc(.a(sel_rd2E),.b(sign_immE),.sel(alusrcBE),.y(srcB));

alu alu(
    .clk(clk),
    .rst(rst),
    .a(sel_rd1E),
    .b(srcB),
    .aluop(alucontrolE),
    .hilo(hilo),
    .cp0_data_o(cp0_data_oE),
//    .div_ready(div_ready), 
//    .state_div(state_div),
//    .start_div(start_div),
//    .signed_div(signed_div),
    .stall_div(stall_divE),
    .y(alu_resE),
    .aluout_64(aluout_64E),
    .overflow(overflow),
    .zero() // wire zero ==> branch跳转控制（已经升级到*控制冒险*）
);

adder pc_8(
    .a(pc_plus4E),
    .b(32'h4),
    .y(pc_plus8E)
);

// link????????alu_resE????????????????
mux2 alu_pc8(
    .a(alu_resE),
    .b(pc_plus8E),
    .sel((balE | jalE) | jrE),
    .y(alu_resE_real)
);

// TODO ??div?????datapath????
//assign hilo_in_signal=((alucontrolE ==`ALUOP_DIV) | (alucontrolE ==`ALUOP_DIVU))? 1:0;
//mux2 #(64) mux2_hiloin(.a(aluout_64M),.b(div_resultM),.sel(hilo_in_signal),.y(hilo_i));
//// ????
//flopenrc DFF_div_stallE      (clk,rst,clear,ena,stallE,div_stallE);
//div mydiv(
//	.clk(clk),
//	.rst(rst),
//	.ena(~div_stallE),
//	.signed_div_i(signed_div), 
//	.opdata1_i(sel_rd1E),
//	.opdata2_i(srcB),
	
//	.state(state_div),
//	.start_i(start_div),
//	.annul_i(1'b0),
//	.result_o(div_result),
//	.ready_o(div_ready)
//);

// 除法
//div mydiv(
//	.clk(clk),
//	.rst(rst),
//	.signed_div_i(signed_div), 
//	.opdata1_i(sel_rd1E),
//	.opdata2_i(srcB),
//	.start_i(start_div),
//	.annul_i(1'b0),
//	.result_o(div_result),
//	.ready_o(div_ready)
//);

// ====================================== Memory ======================================
flopenrc DFF_alu_resM         (clk,rst,clear|(|exceptM),ena,alu_resE_real,alu_resM);
flopenrc DFF_sel_rd2M         (clk,rst,clear|(|exceptM),ena,sel_rd2E,sel_rd2M);
flopenrc #(5) DFF_reg_waddrM  (clk,rst,clear|(|exceptM),ena,reg_waddrE,reg_waddrM);
flopenrc DFF_instrM           (clk,rst,clear|(|exceptM),ena,instrE,instrM);
flopenrc #(64) DFF_aluout_64M (clk,rst,clear|(|exceptM),ena,aluout_64E,aluout_64M);
flopenrc DFF_pc_nowM          (clk,rst,clear|(|exceptM),ena,pc_nowE,pc_nowM);
flopenrc #(8) DFF_exceptM(clk,rst,clear|(|exceptM),ena,{exceptE[7:3],overflow,exceptE[1:0]},exceptM);
flopenrc #(1) DFF_is_in_delayslotM(clk,rst,clear|(|exceptM),ena,is_in_delayslotE,is_in_delayslotM);
flopenrc #(5) DFF_reg_rdM  (clk,rst,clear|(|exceptM),ena,rdE,rdM);
// ******************* wys??????????????? *****************
// M???д??hilo
hilo_reg hilo_reg(
	.clk(clk),.rst(rst),.we(hilowriteM),
	.hilo_i(aluout_64M),
	// .hilo_res(hilo_res)
	.hilo(hilo)  // hilo current data
    );

//assign data_sram_waddr = alu_resM;
assign data_sram_waddr = (alu_resM[31:28] == 4'hB) ? {4'h1, alu_resM[27:0]} :
                (alu_resM[31:28] == 4'h8) ? {4'h0, alu_resM[27:0]}: 32'b0;

// ???????
lsmem lsmen(
    .opM(instrM[31:26]),
    .sel_rd2M(sel_rd2M), // writedata_4B
    .alu_resM(alu_resM),
    .data_sram_rdataM(data_sram_rdataM),
    .pcM(pc_nowM),

    .data_sram_wenM(data_sram_wenM),
    .data_sram_wdataM(data_sram_wdataM),
    .read_dataM(read_dataM),
    .adesM(adesM),
    .adelM(adelM),
    .bad_addr(bad_addr)
);

exception exp(rst,exceptM,adelM,adesM,status_o,cause_o,excepttypeM);

cp0_reg CP0(
    .clk(clk),
	.rst(rst),

	.we_i(cp0writeM),
	.waddr_i(rdM),  // M阶段写入CP0
	.raddr_i(rdE),  // E阶段读取CP0，这两步可以避免数据冒险处理
	.data_i(sel_rd2M),

	.int_i(6'b000000),

	.excepttype_i(excepttypeM),
	.current_inst_addr_i(pc_nowM),
	.is_in_delayslot_i(is_in_delayslotM),
	.bad_addr_i(bad_addr),

	.data_o(cp0_data_oE),
	.count_o(count_o),
	.compare_o(compare_o),
	.status_o(status_o),
	.cause_o(cause_o),
	.epc_o(epc_o),
	.config_o(config_o),
	.prid_o(prid_o),
	.badvaddr_o(badvaddr),
	.timer_int_o(timer_int_o)
);

// ====================================== WriteBack ======================================
flopenrc DFF_alu_resW         (clk,rst,clear,ena,alu_resM,alu_resW);
flopenrc DFF_data_sram_rdataW (clk,rst,clear,ena,read_dataM,data_sram_rdataW);
flopenrc #(5) DFF_reg_waddrW  (clk,rst,clear,ena,reg_waddrM,reg_waddrW);
flopenrc DFF_pc_nowW          (clk,rst,clear,ena,pc_nowM,pc_nowW);


mux2 mux2_memtoReg(.a(alu_resW),.b(data_sram_rdataW),.sel(memtoRegW),.y(wd3W));

// ******************* ??????????? *****************
hazard hazard(
    regwriteE,regwriteM,regwriteW,memtoRegE,memtoRegM,branchD,jrD,stall_divE,
    rsD,rtD,rsE,rtE,reg_waddrM,reg_waddrW,reg_waddrE,
    stallF,stallD,stallE,flushE,forwardAD,forwardBD,
    forwardAE, forwardBE,

    instrM[31:26],
    excepttypeM,
    epc_o,
    newpcM
);
//always @(posedge clk) begin
//    if(alucontrolE==`ALUOP_DIV || alucontrolE==`ALUOP_DIVU) begin
////        $display("alucontrolE: %b",alucontrolE);
////        $display("hi: %h", hilo_i[63:32]);
////        $display("lo: %h", hilo_i[31:0]);
//        $display("instrD: %b", instrD);
//        $display("stallD: %b", stallD);
//        $display("stallF: %b", stallF);
//        $display("stallE: %b", stallE);
//        $display("div_ready: %b",div_ready);
//      end
//    end
endmodule