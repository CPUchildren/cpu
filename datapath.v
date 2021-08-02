`timescale 1ns / 1ps
`include "defines.vh"
module datapath (
    input wire clk,rst,i_stall,d_stall,
    input wire [31:0]instrF,data_sram_rdataM,

    output wire memenM,longest_stall,
    output wire [3:0] data_sram_wenM,
    output wire [31:0]pc_now,data_sram_waddr,
    output wire [31:0]data_sram_wdataM,
    // except 
    input wire [5:0]ext_int,
    output wire [31:0]excepttypeM,
    output wire [31:0]instrD,instrE,instrM
);

// ====================================== ���������� ======================================
wire clear,ena;
wire [63:0]hilo;
// F
wire is_in_delayslotF;
wire [31:0]pc_plus4F,pc_next,pc_next_jump,pc_next_jr;
wire [7:0] exceptF;
// D
wire syscallD,breakD,eretD;
wire forwardAD,forwardBD;
wire pcsrcD,equalD,branchD,jumpD,jrD,balD,jalD;
wire [31:0]pc_nowD,pc_plus4D,pc_branchD,rd1D,rd2D,rd1D_branch,rd2D_branch;
wire [31:0]instrD_sl2,sign_immD,sign_immD_sl2;
wire [7:0] exceptD;
wire invalidD, is_in_delayslotD;
// E
wire regdstE,alusrcAE,alusrcBE,regwriteE,memtoRegE,jrE,balE,jalE,stall_divE;
wire [1:0]forwardAE,forwardBE;
wire [4:0]rtE,rdE,rsE,saE,reg_waddrE;
wire [7:0]alucontrolE;
wire [31:0]rd1E,rd2E,srcB,sign_immE,pc_plus4E,pc_plus8E,rd1_saE;
wire [31:0]pc_nowE,alu_resE,sel_rd1E,sel_rd2E,alu_resE_real,cp0_data_oE;
wire [63:0]div_result,aluout_64E;
wire [7:0] exceptE;
wire overflow, is_in_delayslotE;
// M
wire memtoRegM,regwriteM,memWriteM;
wire [4:0]reg_waddrM;
wire [31:0]pc_nowM,alu_resM,read_dataM,sel_rd2M,rd2M;
wire [63:0]div_resultM,aluout_64M;
wire [31:0]if_addr;
wire [7:0] exceptM;
wire adelM,adesM;
wire [31:0] newpcM;
wire [31:0] bad_addr;
wire is_in_delayslotM;
wire [4:0]rdM;
// W
wire memtoRegW,regwriteW,balW,jalW,hilowriteM,cp0writeM;
wire [4:0]reg_waddrW;
wire [31:0]pc_nowW, alu_resW, wd3W, data_sram_rdataW;
//cp0
wire[`RegBus] count_o,compare_o,status_o,cause_o,epc_o,config_o,prid_o;
wire[`RegBus] data_o,badvaddr;
wire timer_int_o;
// stall
wire stallF,stallD,stallE,stallM,stallW;
// flush
wire flushD,flushE,flushM,flushW;
// instrD �ֽ�
wire [5:0]opD,functD;
wire [4:0]rsD,rtD,rdD,saD;

assign clear = 1'b0;
assign ena = 1'b1;
// ====================================== Fetch ======================================
// �쳣
assign exceptF = (pc_now[1:0] == 2'b00) ? 8'b00000000 : 8'b10000000;
assign is_in_delayslotF = (jumpD|jrD|jalD|branchD); // �ӳٲ۵�ȡָʱ���ж���һ���Ƿ��Ƿ�ָ֧��

pc_mux pc_mux(
    .jumpD(jumpD),
    .jalD(jalD),
    .jrD(jrD),
    .pcsrcD(pcsrcD),
    .excepttypeM(excepttypeM),
    .pc_next_jump(pc_next_jump),
    .pc_next_jr(pc_next_jr),
    .pc_plus4F(pc_plus4F),
    .pc_branchD(pc_branchD),
    .newpcM(newpcM),
    .pc_next(pc_next)
);

// XXX �����excepttypeM���Ǻܶ���
pc pc(
    .clk(clk),
    .rst(rst),
    .ena(~stallF | (|excepttypeM)),
    .din(pc_next),
    .dout(pc_now)
);

adder adder(
    .a(pc_now),
    .b(32'd4),
    .y(pc_plus4F)
);

// ====================================== Decoder ======================================
flopenrc #(32) DFF_pc_nowD         (clk,rst,flushD,~stallD & ~(|excepttypeM),pc_now,pc_nowD);
flopenrc #(1 ) DFF_is_in_delayslotD(clk,rst,flushD,~stallD,is_in_delayslotF,is_in_delayslotD);
flopenrc #(8 ) DFF_exceptD         (clk,rst,flushD,~stallD,exceptF,exceptD);
flopenrc #(32) DFF_instrD          (clk,rst,flushD,~stallD,instrF,instrD);
flopenrc #(32) DFF_pc_plus4D       (clk,rst,flushD,~stallD,pc_plus4F,pc_plus4D);

// �쳣
assign syscallD = (instrD[31:26] == 6'b000000 && instrD[5:0] == 6'b001100);
assign breakD = (instrD[31:26] == 6'b000000 && instrD[5:0] == 6'b001101);
assign eretD = (instrD == 32'b01000010000000000000000000011000);

// instrD �ֽ�
assign opD = instrD[31:26];
assign rsD = instrD[25:21];
assign rtD = instrD[20:16];
assign rdD = instrD[15:11];
assign saD = instrD[10:6];
assign functD = instrD[5:0];

main_dec main_dec(
    .clk(clk),
    .rst(rst),
    .flushE(flushE),
    .flushM(flushM),
    .flushW(flushW),
    .stallE(stallE),
    .stallM(stallM),
    .stallW(stallW),
    .op(opD),
    .funct(functD),
    .rs(rsD),
    .rt(rtD),
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
    .memenM(memenM),
    .invalid(invalidD)
);

alu_dec alu_decoder(
    .clk(clk), 
    .rst(rst),
    .flushE(flushE),
    .stallE(stallE),
    .op(opD),
    .funct(functD),
    .rs(rsD),
    .aluopE(alucontrolE)
);

regfile regfile(
	.clk(clk),
	.we3(regwriteW & ~stallW), // ������ʱ����д
	.ra1(instrD[25:21]), 
    .ra2(instrD[20:16]),
    .wa3(reg_waddrW),
	.wd3(wd3W), 
	.rd1(rd1D),
    .rd2(rd2D)
);
                            
// ******************* ����ð�� *****************
// �� regfile ��������һ���ж���ȵ�ģ�飬������ǰ�ж� beq���Խ���ָ֧����ǰ��Decode�׶Σ�Ԥ�⣩
mux2 #(32) mux2_forwardAD(rd1D,alu_resM,forwardAD,rd1D_branch);
mux2 #(32) mux2_forwardBD(rd2D,alu_resM,forwardBD,rd2D_branch);
eqcmp pc_predict(
    .a(rd1D_branch),
    .b(rd2D_branch),
    .op(instrD[31:26]),
    .rt(rtD),
    .y(equalD)
);

// PC_j
sl2 sl2_instr(
    .a(instrD),
    .y(instrD_sl2)
);
assign pcsrcD = equalD & (branchD|balD);
assign pc_next_jump={pc_plus4D[31:28],instrD_sl2[27:0]};
assign pc_next_jr=rd1D_branch;

// pc_b 
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

// ====================================== Execute ======================================
flopenrc #(32) DFF_pc_nowE         (clk,rst,flushE,~stallE & ~(|excepttypeM),pc_nowD,pc_nowE);
flopenrc #(1 ) DFF_is_in_delayslotE(clk,rst,flushE,~stallE,is_in_delayslotD,is_in_delayslotE);
flopenrc #(5 ) DFF_rtE             (clk,rst,flushE,~stallE,rtD,rtE);
flopenrc #(5 ) DFF_rdE             (clk,rst,flushE,~stallE,rdD,rdE);
flopenrc #(5 ) DFF_rsE             (clk,rst,flushE,~stallE,rsD,rsE);
flopenrc #(5 ) DFF_saE             (clk,rst,flushE,~stallE,saD,saE);
flopenrc #(8 ) DFF_exceptE         (clk,rst,flushE,~stallE,{exceptD[7],syscallD,breakD,eretD,invalidD,exceptD[2:0]},exceptE);
flopenrc #(32) DFF_instrE          (clk,rst,flushE,~stallE,instrD,instrE);
flopenrc #(32) DFF_pc_plus4E       (clk,rst,flushE,~stallE,pc_plus4D,pc_plus4E);
flopenrc #(32) DFF_rd1E            (clk,rst,flushE,~stallE,rd1D,rd1E);
flopenrc #(32) DFF_rd2E            (clk,rst,flushE,~stallE,rd2D,rd2E);
flopenrc #(32) DFF_sign_immE       (clk,rst,flushE,~stallE,sign_immD,sign_immE);

// linkָ��ԼĴ�����ѡ��
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
// ******************* ����ð�� *****************
// 00ԭ�����01д�ؽ��_W�� 10������_M
mux3 #(32) mux3_forwardAE(rd1_saE,wd3W,alu_resM,forwardAE,sel_rd1E);
mux3 #(32) mux3_forwardBE(rd2E,wd3W,alu_resM,forwardBE,sel_rd2E);

mux2 mux2_aluSrcBE(
    .a(sel_rd2E),
    .b(sign_immE),
    .sel(alusrcBE),
    .y(srcB)
);

alu alu(
    .clk(clk),
    .rst(rst),
    .a(sel_rd1E),
    .b(srcB),
    .aluop(alucontrolE),
    .hilo(hilo),
    .cp0_data_o(cp0_data_oE),
    .stall_div(stall_divE),
    .y(alu_resE),
    .aluout_64(aluout_64E),
    .overflow(overflow),
    .zero()
);

adder pc_8(
    .a(pc_plus4E),
    .b(32'h4),
    .y(pc_plus8E)
);

// �����ӳٲۣ���link��pc+8
mux2 alu_pc8(
    .a(alu_resE),
    .b(pc_plus8E),
    .sel((balE | jalE) | jrE),
    .y(alu_resE_real)
);

// ====================================== Memory ======================================
flopenrc #(32) DFF_pc_nowM         (clk,rst,flushM,~stallM & ~(|excepttypeM),pc_nowE,pc_nowM);
flopenrc #(1 ) DFF_is_in_delayslotM(clk,rst,flushM,~stallM,is_in_delayslotE,is_in_delayslotM);
flopenrc #(5 ) DFF_reg_waddrM      (clk,rst,flushM,~stallM,reg_waddrE,reg_waddrM);
flopenrc #(5 ) DFF_reg_rdM         (clk,rst,flushM,~stallM,rdE,rdM);
flopenrc #(8 ) DFF_exceptM         (clk,rst,flushM,~stallM,{exceptE[7:3],overflow,exceptE[1:0]},exceptM);
flopenrc #(32) DFF_alu_resM        (clk,rst,flushM,~stallM,alu_resE_real,alu_resM);
flopenrc #(32) DFF_sel_rd2M        (clk,rst,flushM,~stallM,sel_rd2E,sel_rd2M);
flopenrc #(32) DFF_instrM          (clk,rst,flushM,~stallM,instrE,instrM);
flopenrc #(64) DFF_aluout_64M      (clk,rst,flushM,~stallM,aluout_64E,aluout_64M);

// ��ַӳ��
// assign data_sram_waddr = alu_resM;
assign data_sram_waddr = (alu_resM[31:28] == 4'hB) ? {4'h1, alu_resM[27:0]} :
                (alu_resM[31:28] == 4'h8) ? {4'h0, alu_resM[27:0]}: 32'b0;

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

exception exp(
    rst,
    exceptM,
    adelM,
    adesM,
    status_o,
    cause_o,
    excepttypeM
);

hilo_reg hilo_reg(
	.clk(clk),.rst(rst),.we(hilowriteM & ~(|excepttypeM)), // д��ʱ��û���쳣
	.hilo_i(aluout_64M),
	// .hilo_res(hilo_res)
	.hilo(hilo)  // hilo current data
);

cp0_reg CP0(
    .clk(clk),
	.rst(rst),

	.we_i(cp0writeM),
	.waddr_i(rdM),  // M�׶�д��CP0
	.raddr_i(rdE),  // E�׶ζ�ȡCP0�����������Ա�������ð�մ���
	.data_i(sel_rd2M),

	.int_i(ext_int),

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
flopenrc #(5 ) DFF_reg_waddrW      (clk,rst,clear,~stallW,reg_waddrM,reg_waddrW);
flopenrc #(32) DFF_alu_resW        (clk,rst,clear,~stallW,alu_resM,alu_resW);
flopenrc #(32) DFF_data_sram_rdataW(clk,rst,clear,~stallW,read_dataM,data_sram_rdataW);
flopenrc #(32) DFF_pc_nowW         (clk,rst,clear,~stallW & ~(|excepttypeM),pc_nowM,pc_nowW);

mux2 mux2_memtoReg(.a(alu_resW),.b(data_sram_rdataW),.sel(memtoRegW),.y(wd3W));

// ******************* ð�մ��� *****************
// wire [31:0]excepttypeM_save;
// always @(posedge clk) begin
//     if(rst) excepttypeM_save <= 32'b0;
//     else excepttypeM_save <= excepttypeM;
// end

hazard hazard(
    .regwriteE(regwriteE),
    .regwriteM(regwriteM),
    .regwriteW(regwriteW),
    .memtoRegE(memtoRegE),
    .memtoRegM(memtoRegM),
    .pcsrcD(pcsrcD),
    .jumpD(jumpD),
    .jalD(jalD),
    .branchD(branchD),
    .jrD(jrD),
    .stall_divE(stall_divE),
    .i_stall(i_stall),
    .d_stall(d_stall),
    .rsD(rsD),
    .rtD(rtD),
    .rsE(rsE),
    .rtE(rtE),
    .reg_waddrM(reg_waddrM),
    .reg_waddrW(reg_waddrW),
    .reg_waddrE(reg_waddrE),
    
    .forwardAD(forwardAD),
    .forwardBD(forwardBD),
    .forwardAE(forwardAE), 
    .forwardBE(forwardBE),
    .stallF(stallF),
    .stallD(stallD),
    .stallE(stallE),
    .stallM(stallM),
    .stallW(stallW),
    .longest_stall(longest_stall),
    .flushD(flushD),
    .flushE(flushE),
    .flushM(flushM),
    .flushW(flushW),
    
    // �쳣
    .opM(instrM[31:26]),
    .excepttypeM(excepttypeM),
    // .excepttypeM_save(excepttypeM_save),
    .cp0_epcM(epc_o),
    .newpcM(newpcM)
);
endmodule