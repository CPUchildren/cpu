`timescale 1ns / 1ps

module mips(
	input wire clk,rst,
	input wire[31:0] instr,data_ram_rdata, // 前in 后out
	output wire memWriteM, 
	output wire[3:0] sel,
	output wire[31:0] pc,data_ram_waddr,data_ram_wdataM
);
	
	wire regwriteW,regdstE,alusrcAE,alusrcE,branchD,memtoRegW,jumpD;
	// 数据冒险添加信号
	wire regwriteE,regwriteM,memtoRegE,memtoRegM;
	wire[2:0] alucontrolE;
	wire [31:0]instrD;
	

//	// 注意：这里的指令就是直接来源于datapath中提供的instrD
//	controller controller(
//		clk,rst,
//		instrD, // 前in - 后out
//		regwriteW,regdstE,alusrcAE,alusrcE,branchD,memWriteM,memtoRegW,jumpD, // input wire 
//    	// 数据冒险添加信号
//		regwriteE,regwriteM,memtoRegE,memtoRegM, // input wire 
//		alucontrolE
//	);

	datapath datapath(
		// clk,rst, // input wire 
//		regwriteW,regdstE,alusrcAE,alusrcE,branchD,memWriteM,memtoRegW,jumpD, // input wire 
//		alucontrolE, // input wire [2:0]
		// 数据冒险添加信号
//		regwriteE,regwriteM,memtoRegE,memtoRegM, // input wire 
		// instr,data_ram_rdata, // input wire [31:0]
		// sel,
		// instrD,pc,data_ram_waddr,data_ram_wdataM // output wire [31:0]
		.clk(clk),.rst(rst),
    	.instrF(instr),
		.data_ram_rdataM(data_ram_rdata),
    	.instrD(instrD),
		.pc_now(pc),
		.data_ram_waddr(data_ram_waddr),
    	.sel(sel),
    	.writedataM(data_ram_wdataM) //writedataM
	);

endmodule
