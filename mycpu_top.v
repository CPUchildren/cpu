module mycpu_top(
    input clk,
    input resetn,  //low active
    input [5:0]int,  //interrupt,high active
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

    wire i_stall,d_stall;
    assign i_stall = 1'b0;
    assign d_stall = 1'b0;
    // cpu master
    datapath datapath(
		.clk(~clk),
        .rst(~resetn), // to high active
        .i_stall(i_stall), // input
        .d_stall(d_stall), // input
        .longest_stall(), // output
        // instr
        .pc_nowF(inst_sram_addr),
        .inst_sram_rdataF(inst_sram_rdata),
        .inst_sram_enF(inst_sram_en),
        // data
        .data_sram_enM(data_sram_en),
        .data_sram_wenM(data_sram_wen),
        .data_sram_waddrM(data_sram_addr),
        .data_sram_wdataM(data_sram_wdata),
        .data_sram_rdataM(data_sram_rdata),
        // except
        .ext_int(int),
        .except_logicM()
	);

    // instr
    assign inst_sram_wen = 4'b0;
    assign inst_sram_wdata = 32'b0;

    // debug
    assign debug_wb_pc          = datapath.pc_nowM;
    assign debug_wb_rf_wen      = {4{datapath.regfile.we3}};
    assign debug_wb_rf_wnum     = datapath.regfile.wa3;
    assign debug_wb_rf_wdata    = datapath.regfile.wd3;

    //ascii
    instdec instdec(
        .instr(inst_sram_rdata)
    );

endmodule