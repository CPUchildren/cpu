module mycpu_top(
    input clk,
    input resetn,  //low active
    input ext_int,  //interrupt,high active
    //cpu inst sram
    output        inst_sram_en   ,
    output [3 :0] inst_sram_wen  ,
    output [31:0] inst_sram_addr ,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata,
    //cpu data sram
    output        data_sram_en   ,
    output [3 :0] data_sram_wen  ,
    output [31:0] data_sram_addr ,
    output [31:0] data_sram_wdata,
    input  [31:0] data_sram_rdata,
    //debug
    output [31:0] debug_wb_pc     ,
    output [3:0] debug_wb_rf_wen  ,
    output [4:0] debug_wb_rf_wnum ,
    output [31:0] debug_wb_rf_wdata
);

    // 一个例子
	// wire [31:0] pc;
	// wire [31:0] instr;
	wire memwrite;
    wire [3:0]sel;
	// wire [31:0] aluout, writedata, readdata;

    datapath datapath(
		.clk(clk),
        .rst(~resetn), // to high active
        // instr
        .pc_now(inst_sram_addr),
        .instrF(inst_sram_rdata),
        // data
        // .memWriteM(memwrite),
        .data_sram_rdataM(data_sram_rdata),
        .data_sram_waddr(data_sram_addr),
        .data_sram_wdataM(data_sram_wdata),
        .data_sram_wenM(data_sram_wen)
	);

    // instr
    assign inst_sram_en = 1'b1;     //如果有inst_en，就用inst_en
    assign inst_sram_wen = 4'b0;
    assign inst_sram_wdata = 32'b0;
    // assign inst_sram_addr = pc;
    // assign instr = inst_sram_rdata;

    // data
    assign data_sram_en = 1'b1;     //如果有data_en，就用data_en
    // assign data_sram_wen = {4{memwrite}};
    // assign data_sram_wen = sel;
    // assign data_sram_addr = aluout;
    // assign data_sram_wdata = writedata;
    // assign readdata = data_sram_rdata;

    // debug
    assign debug_wb_pc          = datapath.pc_nowW;
    assign debug_wb_rf_wen      = {4{datapath.regwriteW}}; 
    assign debug_wb_rf_wnum     = datapath.reg_waddrW;
    assign debug_wb_rf_wdata    = datapath.wd3W;

    //ascii
    instdec instdec(
        .instr(instr)
    );

endmodule