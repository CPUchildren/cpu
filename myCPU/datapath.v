`timescale 1ns / 1ps
`include "instrdefines.vh"
module datapath (
    input wire clk,rst,
    input wire [31:0]instrF,data_ram_rdataM,
    output wire [31:0]instrD,pc_now,data_ram_waddr,
    output reg [3:0] sel,
    output reg [31:0] writedataM//data_ram_wdataM
    
);

// ==================== 变量定义区 =======================
wire pcsrcD,clear,ena,equalD; // wire zero ==> branch跳转控制（已经升级到*控制冒险*）
wire stallF,stallD,flushD,flushE,forwardAD,forwardBD;
wire [1:0]forwardAE,forwardBE;
wire [4:0]rtD,rdD,rsD,saD,rtE,rdE,rsE,saE;
wire [4:0]reg_waddrE,reg_waddrM,reg_waddrW;
wire [31:0]pc_plus4F,pc_plus4D,pc_plus4E,pc_plus8E,pc_branchD,pc_next,pc_next_jump,pc_next_jr,pc_next_j,rd1_saE;
wire [31:0]rd1D,rd2D,rd1E,rd2E,wd3W,rd1D_branch,rd2D_branch,sel_rd1E,sel_rd2E, data_ram_wdataM;
reg [31:0] finaldataM,writedataM;
wire [31:0]instrD_sl2,sign_immD,sign_immE,sign_immD_sl2, instrE, instrM;
wire [31:0]srcB,alu_resE,alu_resE_real,alu_resM,alu_resW,data_ram_rdataW;
wire [63:0]hilo,aluout_64E,aluout_64M;
wire regwriteW,regdstE,alusrcAE,alusrcBE,branchD,memWriteM,memtoRegW,jumpD;
wire balD,balE,balW,jalD,jalE,jalW,jrD,jrE,jrW;

// 数据冒险添加信号
wire regwriteE,regwriteM,memtoRegE,memtoRegM;
wire [7:0]alucontrolE;

wire div_ready,start_div,signed_div,stall_divE;
wire hilo_in_signal;
wire [63:0] hilo_i,div_result,div_resultM;
wire stallE;

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
// 注意：这里要不要flushD都没问题，因为跳转指令后面都是一个nop，所以没关系
flopenrc DFF_instrD(clk,rst,flushD,~stallD,instrF,instrD);
flopenrc DFF_pc_plus4D(clk,rst,flushD,~stallD,pc_plus4F,pc_plus4D);


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
    .jrW(jrW)
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
flopenrc #(32) DFF_rd1E(clk,rst,flushE,~stallE,rd1D,rd1E);
flopenrc #(32) DFF_rd2E(clk,rst,flushE,~stallE,rd2D,rd2E);
flopenrc #(32) DFF_sign_immE(clk,rst,flushE,~stallE,sign_immD,sign_immE);
flopenrc #(5) DFF_rtE(clk,rst,flushE,~stallE,rtD,rtE);
flopenrc #(5) DFF_rdE(clk,rst,flushE,~stallE,rdD,rdE);
flopenrc #(5) DFF_rsE(clk,rst,flushE,~stallE,rsD,rsE);
flopenrc #(5) DFF_saE(clk,rst,flushE,~stallE,saD,saE);
flopenrc DFF_instrE(clk,rst,flushE,~stallE,instrD,instrE);
flopenrc DFF_pc_plus4E(clk,rst,flushE,ena,pc_plus4D,pc_plus4E);
mux2 #(5) mux2_regDst(.a(rtE),.b(rdE),.sel(regdstE),.y(reg_waddrE));

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
flopenrc DFF_alu_resM(clk,rst,clear,ena,alu_resE_real,alu_resM);
flopenrc DFF_data_ram_wdataM(clk,rst,clear,ena,sel_rd2E,data_ram_wdataM);
flopenrc #(5) DFF_reg_waddrM(clk,rst,clear,ena,reg_waddrE,reg_waddrM);
// flopenrc #(1) DFF_zeroM(clk,rst,clear,ena,zero,zeroM);  ==> 控制冒险，已将分支指令提前到Decode阶段
flopenrc DFF_instrM(clk,rst,clear,ena,instrE,instrM);
flopenrc #(64) DFF_aluout_64M(clk,rst,clear,ena,aluout_64E,aluout_64M);


// ******************* wys：数据移动相关指令 *****************
// TODO M阶段写回hilo
hilo_reg hilo_reg(
	.clk(clk),.rst(rst),.we(hilowriteM),
	.hilo_i(hilo_i),
	// .hilo_res(hilo_res)
	.hilo(hilo)  // hilo current data
    );

assign data_ram_waddr = alu_resM;
// assign pcsrcM = zeroM & branchM;  ==> 控制冒险，已将分支指令提前到Decode阶段

// TODO =====================访存==============================
always @(*) begin
    case(instrM[31:26])
        `OP_LW,`OP_LB,`OP_LBU,`OP_LH,`OP_LHU: sel <= 4'b0000;
        `OP_SW: begin
            writedataM <= data_ram_wdataM;
            sel <=4'b1111;
        end
        `OP_SH: begin
            writedataM <= {data_ram_wdataM[15:0],data_ram_wdataM[15:0]};
            case(alu_resM[1:0])
                2'b00: sel <= 4'b1100;
                2'b10: sel <= 4'b0011;
                default: ;
            endcase
        end
        `OP_SB: begin
            writedataM <= {data_ram_wdataM[7:0],data_ram_wdataM[7:0],data_ram_wdataM[7:0],data_ram_wdataM[7:0]};
            case(alu_resM[1:0])
                2'b00: sel <= 4'b1000;
                2'b01: sel <= 4'b0100;
                2'b10: sel <= 4'b0010;
                2'b11: sel <= 4'b0001;
                default: ;
            endcase
        end
    endcase
end

always @(*) begin
    case(instrM[31:26])
        `OP_LW: begin
            finaldataM <= data_ram_rdataM;
        end
        `OP_LB: begin
            case(alu_resM[1:0])
                2'b00: finaldataM <= {{24{data_ram_rdataM[31]}},data_ram_rdataM[31:24]};
                2'b01: finaldataM <= {{24{data_ram_rdataM[23]}},data_ram_rdataM[23:16]};
                2'b10: finaldataM <= {{24{data_ram_rdataM[15]}},data_ram_rdataM[15:8]};
                2'b11: finaldataM <= {{24{data_ram_rdataM[7]}},data_ram_rdataM[7:0]};
            endcase
        end
        `OP_LBU: begin
            case(alu_resM[1:0])
                2'b00: finaldataM <= {{24{0}},data_ram_rdataM[31:24]};
                2'b01: finaldataM <= {{24{0}},data_ram_rdataM[23:16]};
                2'b10: finaldataM <= {{24{0}},data_ram_rdataM[15:8]};
                2'b11: finaldataM <= {{24{0}},data_ram_rdataM[7:0]};
            endcase
        end
        `OP_LH: begin
            case(alu_resM[1])
                2'b0: finaldataM <= {{24{data_ram_rdataM[31]}},data_ram_rdataM[31:16]};
                2'b1: finaldataM <= {{24{data_ram_rdataM[15]}},data_ram_rdataM[15:0]};
            endcase
        end
        `OP_LHU: begin
            case(alu_resM[1])
                2'b0: finaldataM <= {{24{0}},data_ram_rdataM[31:16]};
                2'b1: finaldataM <= {{24{0}},data_ram_rdataM[15:0]};
            endcase
        end
        default: ;
    endcase
end

// ====================================== WriteBack ======================================
flopenrc DFF_alu_resW(clk,rst,clear,ena,alu_resM,alu_resW);
flopenrc DFF_data_ram_rdataW(clk,rst,clear,ena,finaldataM,data_ram_rdataW);
flopenrc #(5) DFF_reg_waddrW(clk,rst,clear,ena,reg_waddrM,reg_waddrW);


mux2 mux2_memtoReg(.a(alu_resW),.b(data_ram_rdataW),.sel(memtoRegW),.y(wd3W));

// ******************* 冒险信号总控制 *****************
hazard hazard(
    regwriteE,regwriteM,regwriteW,memtoRegE,memtoRegM,branchD,jrD,stall_divE,
    rsD,rtD,rsE,rtE,reg_waddrM,reg_waddrW,reg_waddrE,
    stallF,stallD,stallE,flushE,forwardAD,forwardBD,
    forwardAE, forwardBE
);

// BUG 测试
// always @(posedge clk) begin
//     $display("alucontrolE: %b----------------------------",alucontrolE);
//     $display("instrD: %h",instrD);
//     $display("rd1D: %h",rd1D);
//     $display("rd1E: %h",rd1E);
//     $display("rd1_saE: %h",rd1_saE);
//     $display("sel_rd1E: %h",sel_rd1E);
//     $display("sel_rd2E: %h",sel_rd2E);
//     $display("srcB: %h",srcB);
//     $display("alu_resE: %h",alu_resE);
//     $display("wd3W: %h",wd3W);
//     $display("reg_waddrW: %d",reg_waddrW);
//     $display("rtD: %d",rtD);
//     $display("rdD: %d",rdD);
//     $display("rtE: %d",rtE);
//     $display("rdE: %d",rdE);
//     $display("reg_waddrE: %d",reg_waddrE);
// end
endmodule