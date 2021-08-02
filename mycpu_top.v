module mycpu_top(
    input wire [5:0] ext_int   ,   // interrupt,high active
    input wire       aclk      ,
    input wire       aresetn   ,   // low active

    //ar
    output [3 :0] arid   ,
    output [31:0] araddr ,
    output [3 :0] arlen  ,
    output [2 :0] arsize ,
    output [1 :0] arburst,
    output [1 :0] arlock ,
    output [3 :0] arcache,
    output [2 :0] arprot ,
    output        arvalid,
    input         arready,
    //r
    input  [3 :0] rid    ,
    input  [31:0] rdata  ,
    input  [1 :0] rresp  ,
    input         rlast  ,
    input         rvalid ,
    output        rready ,
    //aw
    output [3 :0] awid   ,
    output [31:0] awaddr ,
    output [3 :0] awlen  ,
    output [2 :0] awsize ,
    output [1 :0] awburst,
    output [1 :0] awlock ,
    output [3 :0] awcache,
    output [2 :0] awprot ,
    output        awvalid,
    input         awready,
    //w
    output [3 :0] wid    ,
    output [31:0] wdata  ,
    output [3 :0] wstrb  ,
    output        wlast  ,
    output        wvalid ,
    input         wready ,
    //b
    input  [3 :0] bid    ,
    input  [1 :0] bresp  ,
    input         bvalid ,
    output        bready ,

    //debug interface
    output [31:0] debug_wb_pc      ,
    output [3 :0] debug_wb_rf_wen  ,
    output [4 :0] debug_wb_rf_wnum ,
    output [31:0] debug_wb_rf_wdata
);

    // variable define
    // inst sram
    wire        inst_sram_en   ;
    wire [3 :0] inst_sram_wen  ;
    wire [31:0] inst_sram_addr ;
    wire [31:0] inst_sram_wdata;
    wire [31:0] inst_sram_rdata;
    // inst sram like
    wire        inst_req       ;
    wire        inst_wr        ;
    wire [1 :0] inst_size      ;
    wire [31:0] inst_addr      ;
    wire [31:0] inst_wdata     ;
    wire [31:0] inst_rdata     ;
    wire        inst_addr_ok   ;
    wire        inst_data_ok   ;
    // inst cache
    wire        cache_inst_req    ;
    wire        cache_inst_wr     ;
    wire [1 :0] cache_inst_size   ;
    wire [31:0] cache_inst_addr   ;
    wire [31:0] cache_inst_wdata  ;
    wire [31:0] cache_inst_rdata  ;
    wire        cache_inst_addr_ok;
    wire        cache_inst_data_ok;
    // data sram
    wire        data_sram_en   ;
    wire [3 :0] data_sram_wen  ;
    wire [31:0] data_sram_addr ;
    wire [31:0] data_sram_wdata;
    wire [31:0] data_sram_rdata;
    // data sram like
    wire        data_req       ;
    wire        data_wr        ;
    wire [1 :0] data_size      ;
    wire [31:0] data_addr      ;
    wire [31:0] data_wdata     ;
    wire [31:0] data_rdata     ;
    wire        data_addr_ok   ;
    wire        data_data_ok   ;
    // data cache
    wire        no_cache           ;
    wire        cache_data_req     ;
    wire        cache_data_wr      ;
    wire [1 :0] cache_data_size    ;
    wire [31:0] cache_data_addr    ;
    wire [31:0] cache_data_wdata   ;
    wire [31:0] cache_data_rdata   ;
    wire        cache_data_addr_ok ;
    wire        cache_data_data_ok ;
    // datapath
    wire memen; // ,memwrite
    wire longest_stall,i_stall,d_stall;
    // wire [3:0]sel;
    wire [31:0] instrF,instrD,instrE,instrM; // , pc, aluout, writedata, readdata;
    wire [31:0] data_sram_addr_temp,excepttypeM;
    
    // variable assignment
    // instr
    assign inst_sram_en = 1'b1;     //如果有inst_en，就用inst_en
    assign inst_sram_wen = 4'b0;
    // assign inst_sram_addr = pc;
    assign inst_sram_wdata = 32'b0;
    assign instrF = inst_sram_rdata;
    
    // data
    assign data_sram_en = memen;     //如果有data_en，就用data_en
    // assign data_sram_wen = {4{memwrite}};
    // assign data_sram_addr = aluout;
    // assign data_sram_wdata = writedata;
    // assign readdata = data_sram_rdata;
    
    // debug
    assign debug_wb_pc          = datapath.pc_nowW;
    assign debug_wb_rf_wen      = {4{datapath.regwriteW & ~datapath.stallW}}; 
    assign debug_wb_rf_wnum     = datapath.reg_waddrW;
    assign debug_wb_rf_wdata    = datapath.wd3W;

// sub module
    // 地址映射+no_cache判断
    tlb tlb(
        .data_sram_addr_temp(data_sram_addr_temp),
        .no_cache(no_cache),
        .data_sram_addr(data_sram_addr)
    );

    datapath datapath(
		.clk(aclk),
        .rst(~aresetn), // to high active
        // signals
        .i_stall(i_stall), // input
        .d_stall(d_stall), // input
        .longest_stall(longest_stall), // output
        
        // instr
        .pc_now(inst_sram_addr),
        .instrF(inst_sram_rdata),
        
        // data
        .memenM(memen),
        // .memWriteM(memwrite),
        .data_sram_wenM(data_sram_wen),
        .data_sram_waddr(data_sram_addr_temp),
        .data_sram_wdataM(data_sram_wdata),
        .data_sram_rdataM(data_sram_rdata),

        // except
        .ext_int(ext_int),
        .excepttypeM(excepttypeM),
        .instrD(instrD),.instrE(instrE),.instrM(instrM)
	);

    d_sramlike_interface dsramlike_interface(
        .clk(aclk),
        .rst(~aresetn),
        .longest_stall(longest_stall), // one pipline stall -->  one mem visit
        
        // data sram
        .data_sram_en   (data_sram_en   ),
        .data_sram_wen  (data_sram_wen  ),
        .data_sram_addr (data_sram_addr ),
        .data_sram_wdata(data_sram_wdata),
        .data_sram_rdata(data_sram_rdata),
        .d_stall        (d_stall        ) ,  // to let cpu wait return_data

        // sram_like
        .data_req     (data_req     ),
        .data_wr      (data_wr      ),
        .data_size    (data_size    ),
        .data_addr    (data_addr    ),
        .data_wdata   (data_wdata   ),
        .data_rdata   (data_rdata   ),
        .data_addr_ok (data_addr_ok ),
        .data_data_ok (data_data_ok )
    );

    i_sramlike_interface isramlike_interface(
        .clk(aclk),
        .rst(~aresetn),
        .longest_stall(longest_stall), // one pipline stall -->  one mem visit

        // sram
        .inst_sram_en   (inst_sram_en   ),
        .inst_sram_wen  (inst_sram_wen  ),
        .inst_sram_addr (inst_sram_addr ),
        .inst_sram_wdata(inst_sram_wdata),
        .inst_sram_rdata(inst_sram_rdata),
        .i_stall        (i_stall        ),  // to let cpu wait return_data
        
        // sram_like
        .inst_req     (inst_req     ),
        .inst_wr      (inst_wr      ),
        .inst_size    (inst_size    ),
        .inst_addr    (inst_addr    ),
        .inst_wdata   (inst_wdata   ),
        .inst_rdata   (inst_rdata   ),
        .inst_addr_ok (inst_addr_ok ),
        .inst_data_ok (inst_data_ok )
    );
    i_cache_direct_map  i_cache(
        .clk(aclk),    
        .rst(~aresetn),
        .flush(|(excepttypeM)),
        //mips core
        .cpu_inst_req     (inst_req     ),
        .cpu_inst_wr      (inst_wr      ),
        .cpu_inst_size    (inst_size    ),
        .cpu_inst_addr    (inst_addr    ),
        .cpu_inst_wdata   (inst_wdata   ),
        .cpu_inst_rdata   (inst_rdata   ),
        .cpu_inst_addr_ok (inst_addr_ok ),
        .cpu_inst_data_ok (inst_data_ok ),

        //axi interface
        .cache_inst_req    (cache_inst_req    ),
        .cache_inst_wr     (cache_inst_wr     ),
        .cache_inst_size   (cache_inst_size   ),
        .cache_inst_addr   (cache_inst_addr   ),
        .cache_inst_wdata  (cache_inst_wdata  ),
        .cache_inst_rdata  (cache_inst_rdata  ),
        .cache_inst_addr_ok(cache_inst_addr_ok),
        .cache_inst_data_ok(cache_inst_data_ok)
    );
    d_cache_write_through d_cache(
        .clk(aclk),    
        .rst(~aresetn),
        .no_cache(no_cache),
        .flush(|(excepttypeM)),
        // mips core 
        .cpu_data_req    (data_req     ),
        .cpu_data_wr     (data_wr      ),
        .cpu_data_size   (data_size    ),
        .cpu_data_addr   (data_addr    ),
        .cpu_data_wdata  (data_wdata   ),
        .cpu_data_rdata  (data_rdata   ),
        .cpu_data_addr_ok(data_addr_ok ),
        .cpu_data_data_ok(data_data_ok ),

        // axi interface
        .cache_data_req    (cache_data_req    ),
        .cache_data_wr     (cache_data_wr     ),
        .cache_data_size   (cache_data_size   ),
        .cache_data_addr   (cache_data_addr   ),
        .cache_data_wdata  (cache_data_wdata  ),
        .cache_data_rdata  (cache_data_rdata  ),
        .cache_data_addr_ok(cache_data_addr_ok),
        .cache_data_data_ok(cache_data_data_ok)
    );
    cpu_axi_interface cpu_axi_interface(
        .clk(aclk),
        .resetn(aresetn),  // 注意，cpu_axi_interface的rst信号,low active
        .flush(|excepttypeM),
        //inst sram-like 
        .inst_req     (cache_inst_req    ), // cache_inst_req    
        .inst_wr      (cache_inst_wr     ), // cache_inst_wr     
        .inst_size    (cache_inst_size   ), // cache_inst_size   
        .inst_addr    (cache_inst_addr   ), // cache_inst_addr   
        .inst_wdata   (cache_inst_wdata  ), // cache_inst_wdata  
        .inst_rdata   (cache_inst_rdata  ), // cache_inst_rdata  
        .inst_addr_ok (cache_inst_addr_ok), // cache_inst_addr_ok
        .inst_data_ok (cache_inst_data_ok), // cache_inst_data_ok
        
        //data sram-like 
        .data_req     (cache_data_req    ), // cache_data_req    
        .data_wr      (cache_data_wr     ), // cache_data_wr     
        .data_size    (cache_data_size   ), // cache_data_size   
        .data_addr    (cache_data_addr   ), // cache_data_addr   
        .data_wdata   (cache_data_wdata  ), // cache_data_wdata  
        .data_rdata   (cache_data_rdata  ), // cache_data_rdata  
        .data_addr_ok (cache_data_addr_ok), // cache_data_addr_ok
        .data_data_ok (cache_data_data_ok), // cache_data_data_ok

        //axi
        //ar
        .arid         (arid         ),
        .araddr       (araddr       ),
        .arlen        (arlen        ),
        .arsize       (arsize       ),
        .arburst      (arburst      ),
        .arlock       (arlock       ),
        .arcache      (arcache      ),
        .arprot       (arprot       ),
        .arvalid      (arvalid      ),
        .arready      (arready      ),
        //r           
        .rid          (rid          ),
        .rdata        (rdata        ),
        .rresp        (rresp        ),
        .rlast        (rlast        ),
        .rvalid       (rvalid       ),
        .rready       (rready       ),
        //aw          
        .awid         (awid         ),
        .awaddr       (awaddr       ),
        .awlen        (awlen        ),
        .awsize       (awsize       ),
        .awburst      (awburst      ),
        .awlock       (awlock       ),
        .awcache      (awcache      ),
        .awprot       (awprot       ),
        .awvalid      (awvalid      ),
        .awready      (awready      ),
        //w          
        .wid          (wid          ),
        .wdata        (wdata        ),
        .wstrb        (wstrb        ),
        .wlast        (wlast        ),
        .wvalid       (wvalid       ),
        .wready       (wready       ),
        //b           
        .bid          (bid          ),
        .bresp        (bresp        ),
        .bvalid       (bvalid       ),
        .bready       (bready       )
    );

    //ascii
    instdec instdecF(
        .instr(instrF)
    );
    instdec instdecD(
        .instr(instrD)
    );
    instdec instdecE(
        .instr(instrE)
    );
    instdec instdecM(
        .instr(instrM)
    );

endmodule