`timescale 1ns / 1ps
`include "instrdefines.vh"
module datapath (
    input wire clk,rst,
    input wire [31:0]instrF,data_ram_rdataM,
    output wire [31:0]instrD,pc_now,data_ram_waddr,
    // output reg [3:0] sel,
    output reg [31:0] writedataM//data_ram_wdataM
    
);

// ==================== 变量定义区 =======================
wire pcsrcD,clear,ena,equalD; // wire zero ==> branch跳转控制（已经升级到*控制冒险*）
wire stallF,stallD,flushD,flushE,forwardAD,forwardBD;
wire [1:0]forwardAE,forwardBE;
wire [4:0]rtD,rdD,rsD,saD,rtE,rdE,rsE,saE;
wire [4:0]reg_waddrE,reg_waddrM,reg_waddrW;
wire [31:0]pc_plus4F,pc_plus4D,pc_branchD,pc_next,pc_next_jump,rd1_saE;
wire [31:0]rd1D,rd2D,rd1E,rd2E,wd3W,rd1D_branch,rd2D_branch,sel_rd1E,sel_rd2E, data_ram_wdataM;
reg [31:0] finaldataM,writedataM;
wire [31:0]instrD_sl2,sign_immD,sign_immE,sign_immD_sl2, instrE, instrM;
wire [31:0]srcB,alu_resE,alu_resM,alu_resW,data_ram_rdataW;
wire [63:0]hilo,aluout_64E,aluout_64M;
wire regwriteW,regdstE,alusrcAE,alusrcBE,branchD,memWriteM,memtoRegW,jumpD;
// 数据冒险添加信号
wire regwriteE,regwriteM,memtoRegE,memtoRegM;
wire [7:0]alucontrolE;

// BUG 是不是写复杂了
// // 数据移动指令 HILO 相关定义
// wire [31:0]HI,LO;     // 定义hi和lo寄存器最新的值。
// wire [31:0]hi_i,lo_i; // 输入的的HI，LO寄存器的值。
// wire [31:0]hilo_dataE,hilo_dataM,hilo_dataW; // 要写到HILO特殊寄存器的数值。
// wire HI_IN,LO_IN;     // E阶段判断要将值写入HI还是LO。
// wire HI_OUT,LO_OUT;   // E阶段判断要取出HI还是LO的值。
// wire [31:0]hi_E,lo_E; // E执行阶段要写入HI，LO寄存器的值
// wire [31:0]hi_M,lo_M; // M访存阶段要写入HI，LO寄存器的值。
// wire [31:0]hi_W,lo_W; // W回写阶段要写入HI，LO寄存器的值
// wire wehilo_E,wehilo_M,wehilo_W; //处于访存和回写阶段的指令是否要写入HI，LO寄存器

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
// 注意：这里要不要flushD都没问题，因为跳转指令后面都是一个nop，所以没关系
flopenrc DFF_instrD(clk,rst,flushD,~stallD,instrF,instrD);
flopenrc DFF_pc_plus4D(clk,rst,clear,~stallD,pc_plus4F,pc_plus4D);


main_dec main_dec(
    .clk(clk),
    .rst(rst),
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
    .hilowriteM(hilowriteM)
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
flopenrc DFF_data_ram_wdataM(clk,rst,clear,ena,sel_rd2E,data_ram_wdataM);
flopenrc #(5) DFF_reg_waddrM(clk,rst,clear,ena,reg_waddrE,reg_waddrM);
// flopenrc #(1) DFF_zeroM(clk,rst,clear,ena,zero,zeroM);  ==> 控制冒险，已将分支指令提前到Decode阶段
flopenrc DFF_instrM(clk,rst,clear,ena,instrE,instrM);
flopenrc #(64) DFF_aluout_64M(clk,rst,clear,ena,aluout_64E,aluout_64M);

// BUG hilo
//flopenrc DFF_hiM(clk,rst,1'b0,1'b1,hi_E,hi_M);
//flopenrc DFF_loM(clk,rst,1'b0,1'b1,lo_E,lo);
//flopenrc DFF_wehiloM(clk,rst,1'b0,1'b1,wehilo_E,wehilo_M);
//flopenrc DFF_hilodataM(clk,rst,1'b0,1'b1,hilo_dataE,hilo_dataM);

// ******************* wys：数据移动相关指令 *****************
// TODO M阶段写回hilo
hilo_reg hilo_reg(
	.clk(clk),.rst(rst),.we(hilowriteM),
	.hilo_i(aluout_64M),
	// .hilo_res(hilo_res)
	.hilo(hilo)  // hilo current data
    );
// BUG 是不是麻烦了
// always @ (*) begin
//     if(rst == 1) begin
//     {HI,LO} <= {`ZeroWord,`ZeroWord};
//     end else if(wehilo_M == 1) begin
//     {HI,LO} <= {hi_M,lo_M};   // 访存阶段的指令要写HI、LO寄存器
//     end else if(wehilo_W == 1) begin
//     {HI,LO} <= {hi_W,lo_W};     // 回写阶段的指令要写HI、LO寄存器
//     end else begin
//     {HI,LO} <= {hi_i,lo_i};
//     end
// end
// always @(HI_IN,LO_IN,HI_OUT,LO_OUT) begin
//     if (HI_IN) begin
//         wehilo_E<=1'b1;  // 要写入hilo寄存器。
//         hi_E<=rd1D;      // 要将rd1写入hi
//         lo_E<=LO;        // lo值不变
//         holi_dataE<=`ZeroWord   // holi不向通用寄存器传数据
//     end
//     else if (LO_IN) begin
//         wehilo_E<=1'b1;
//         hi_E<=HI;   
//         lo_E<=rd1D;   // 要将rd1写入lo
//         holi_dataE<=`ZeroWord
//     end
//     else if (HI_OUT) begin
//         wehilo_E<=1'b0; // 不写入hilo寄存器
//         hi_E<=HI;
//         lo_E<=LO;
//         holi_dataE<=HI; //将hi的值向后传，写入通用寄存器中
//     end
//     else if (HI_OUT) begin
//         wehilo_E<=1'b0;
//         hi_E<=HI;
//         lo_E<=LO;
//         holi_dataE<=LO; //将hi的值向后传
//     end
// end

assign data_ram_waddr = alu_resM;
// assign pcsrcM = zeroM & branchM;  ==> 控制冒险，已将分支指令提前到Decode阶段

// TODO =====================访存==============================
// always @(*) begin
//     case(instrM[31:26])
//         `OP_LW,`OP_LB,`OP_LBU,`OP_LH,`OP_LHU: sel <= 4'b0000;
//         `OP_SW: begin
//             writedataM <= data_ram_wdataM;
//             sel <=4'b1111;
//         end
//         `OP_SH: begin
//             writedataM <= {data_ram_wdataM[15:0],data_ram_wdataM[15:0]};
//             case(alu_resM[1:0])
//                 2'b00: sel <= 4'b1100;
//                 2'b10: sel <= 4'b0011;
//                 default: ;
//             endcase
//         end
//         `OP_SB: begin
//             writedataM <= {data_ram_wdataM[7:0],data_ram_wdataM[7:0],data_ram_wdataM[7:0],data_ram_wdataM[7:0]};
//             case(alu_resM[1:0])
//                 2'b00: sel <= 4'b1000;
//                 2'b01: sel <= 4'b0100;
//                 2'b10: sel <= 4'b0010;
//                 2'b11: sel <= 4'b0001;
//                 default: ;
//             endcase
//         end
//     endcase
// end

// always @(*) begin
//     case(instrM[31:26])
//         `OP_LW: begin
//             finaldataM <= data_ram_rdataM;
//         end
//         `OP_LB: begin
//             case(alu_resM[1:0])
//                 2'b00: finaldataM <= {{24{data_ram_rdataM[31]}},data_ram_rdataM[31:24]};
//                 2'b01: finaldataM <= {{24{data_ram_rdataM[23]}},data_ram_rdataM[23:16]};
//                 2'b10: finaldataM <= {{24{data_ram_rdataM[15]}},data_ram_rdataM[15:8]};
//                 2'b11: finaldataM <= {{24{data_ram_rdataM[7]}},data_ram_rdataM[7:0]};
//             endcase
//         end
//         `OP_LBU: begin
//             case(alu_resM[1:0])
//                 2'b00: finaldataM <= {{24{0}},data_ram_rdataM[31:24]};
//                 2'b01: finaldataM <= {{24{0}},data_ram_rdataM[23:16]};
//                 2'b10: finaldataM <= {{24{0}},data_ram_rdataM[15:8]};
//                 2'b11: finaldataM <= {{24{0}},data_ram_rdataM[7:0]};
//             endcase
//         end
//         `OP_LH: begin
//             case(alu_resM[1])
//                 2'b0: finaldataM <= {{24{data_ram_rdataM[31]}},data_ram_rdataM[31:16]};
//                 2'b1: finaldataM <= {{24{data_ram_rdataM[15]}},data_ram_rdataM[15:0]};
//             endcase
//         end
//         `OP_LHU: begin
//             case(alu_resM[1])
//                 2'b0: finaldataM <= {{24{0}},data_ram_rdataM[31:16]};
//                 2'b1: finaldataM <= {{24{0}},data_ram_rdataM[15:0]};
//             endcase
//         end
//         default: ;
//     endcase
// end

// ====================================== WriteBack ======================================
flopenrc DFF_alu_resW(clk,rst,clear,ena,alu_resM,alu_resW);
flopenrc DFF_data_ram_rdataW(clk,rst,clear,ena,finaldata,data_ram_rdataW);
flopenrc #(5) DFF_reg_waddrW(clk,rst,clear,ena,reg_waddrM,reg_waddrW);

//flopenrc DFF_hiW(clk,rst,1'b0,1'b1,hi_M,hi_W);
//flopenrc DFF_loW(clk,rst,1'b0,1'b1,lo_M,lo_W);
//flopenrc DFF_wehiloW(clk,rst,1'b0,1'b1,wehilo_M,wehilo_W);
//flopenrc DFF_hilodataW(clk,rst,1'b0,1'b1,hilo_dataM,hilo_dataW);

// BUG 可以直接删掉了
//hiloreg hilo(       // 对hilo寄存器的操作
//    .clk(clk),
//    .rst(rst),
//    .we(wehilo_W),
//    .hi(hi_W),
//    .lo(lo_W),
//    .hi_o(HI),
//    .lo_o(LO)
//);




mux2 mux2_memtoReg(.a(alu_resW),.b(data_ram_rdataW),.sel(memtoRegW),.y(wd3W));

// ******************* 冒险信号总控制 *****************
hazard hazard(
    regwriteE,regwriteM,regwriteW,memtoRegE,memtoRegM,branchD,
    rsD,rtD,rsE,rtE,reg_waddrM,reg_waddrW,reg_waddrE,
    stallF,stallD,flushE,forwardAD,forwardBD,
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