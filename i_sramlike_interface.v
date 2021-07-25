module i_sramlike_interface (
    input  wire clk,rst,
    input  wire longest_stall, // one pipline stall -->  one mem visit

    // sram
    input  wire        inst_sram_en   ,
    input  wire [3 :0] inst_sram_wen  ,
    input  wire [31:0] inst_sram_addr ,
    input  wire [31:0] inst_sram_wdata,
    output wire [31:0] inst_sram_rdata,
    output wire        i_stall,  // to let cpu wait return_data
    
    // sram_like
    output wire        inst_req     ,
    output wire        inst_wr      ,
    output wire [1 :0] inst_size    ,
    output wire [31:0] inst_addr    ,
    output wire [31:0] inst_wdata   ,
    input  wire [31:0] inst_rdata   ,
    input  wire        inst_addr_ok ,
    input  wire        inst_data_ok 
);
    
    reg addr_succ; // 地址握手成功
    reg do_finish; // 完成读写操作
    
    // output信号处理
    // sram like
    assign inst_req  = inst_sram_en & ~addr_succ & ~do_finish;
    assign inst_wr   = 1'b0;
    assign inst_size = 2'b10;
    assign inst_addr  = inst_sram_addr;
    assign inst_wdata = 32'b0;

    // sram
    assign inst_sram_rdata = inst_rdata_temp;
    assign i_stall = inst_sram_en & ~do_finish;

    // addr_succ
    always @(posedge clk) begin
        addr_succ <= rst ? 1'b0:
                     inst_req & inst_addr_ok & ~inst_data_ok ? 1'b1 : // 判断顺序：先req，再addr_ok，再data_ok
                     inst_data_ok ? 1'b0 :
                     addr_succ;
        // BUG display addr_succ_refs
        // $display("inst_req    :%b",inst_req);
        // $display("inst_addr_ok:%b",inst_addr_ok);
        // $display("inst_data_ok:%b",inst_data_ok);
        // $display("addr_succ   :%b",addr_succ);
    end

    // do_finish
    always @(posedge clk) begin
        do_finish <= rst ? 1'b0:
                     inst_data_ok ? 1'b1:
                     ~longest_stall ? 1'b0 : // cpu未阻塞时
                     do_finish;
    end

    // data
    reg [31:0] inst_rdata_temp;
    always @(posedge clk) begin
        inst_rdata_temp <=  rst ? 32'b0:
                            inst_data_ok ? inst_rdata:
                            inst_rdata_temp;
    end

endmodule