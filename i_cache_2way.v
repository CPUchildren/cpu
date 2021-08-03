module i_cache_2way (
    input wire clk,rst,except,no_cache,
    //mips core
    input         cpu_inst_req     ,
    input         cpu_inst_wr      ,
    input  [1 :0] cpu_inst_size    ,
    input  [31:0] cpu_inst_addr    ,
    input  [31:0] cpu_inst_wdata   ,
    output [31:0] cpu_inst_rdata   ,
    output        cpu_inst_addr_ok ,
    output        cpu_inst_data_ok ,

    //axi interface
    output         cache_inst_req     ,
    output         cache_inst_wr      ,
    output  [1 :0] cache_inst_size    ,
    output  [31:0] cache_inst_addr    ,
    output  [31:0] cache_inst_wdata   ,
    input   [31:0] cache_inst_rdata   ,
    input          cache_inst_addr_ok ,
    input          cache_inst_data_ok 
);
    //Cache配置
    parameter  INDEX_WIDTH  = 9, OFFSET_WIDTH = 2, WAY_NUM = 2; 
    localparam TAG_WIDTH    = 32 - INDEX_WIDTH - OFFSET_WIDTH;
    localparam CACHE_DEEPTH = 1 << INDEX_WIDTH;
    
    //Cache存储单元
    reg                 cache_lastused[CACHE_DEEPTH - 1 : 0]; // 每行cache都有1bit lastused标志，0:way1,1:way2
    reg                 cache_valid   [WAY_NUM-1 : 0][CACHE_DEEPTH - 1 : 0];
    reg [TAG_WIDTH-1:0] cache_tag     [WAY_NUM-1 : 0][CACHE_DEEPTH - 1 : 0];
    reg [31:0]          cache_block   [WAY_NUM-1 : 0][CACHE_DEEPTH - 1 : 0];

    //访问地址分解
    wire [OFFSET_WIDTH-1:0] offset;
    wire [INDEX_WIDTH-1:0] index;
    wire [TAG_WIDTH-1:0] tag;
    
    assign offset = cpu_inst_addr[OFFSET_WIDTH - 1 : 0];
    assign index = cpu_inst_addr[INDEX_WIDTH + OFFSET_WIDTH - 1 : OFFSET_WIDTH];
    assign tag = cpu_inst_addr[31 : INDEX_WIDTH + OFFSET_WIDTH];

    //访问Cache line
    wire c_currused;
    wire c_valid;
    wire c_lastused;
    wire [TAG_WIDTH-1:0] c_tag;
    wire [31:0] c_block;
    assign c_currused = (cache_valid[1][index] & (cache_tag[1][index]==tag)) ? 1'b1 : 1'b0;
    assign c_valid = cache_valid[c_currused][index];
    assign c_tag   = cache_tag  [c_currused][index];
    assign c_block = cache_block[c_currused][index];        //数据
    assign c_lastused = cache_lastused[index];
    
    //判断是否命中
    wire hit, miss;
    assign hit = ~no_cache & cpu_inst_req & c_valid & (c_tag == tag); //cache line的valid位为1，且tag与地址中tag相等
    assign miss = cpu_inst_req & (~hit);
    
    //FSM
    parameter IDLE = 2'b00, RM = 2'b01; // i cache只有read
    reg [1:0] state;
    always @(posedge clk) begin
        if(rst) begin
            state <= IDLE;
        end
        else begin
            case(state)
                IDLE:   state <= cpu_inst_req & miss & !except ? RM : IDLE;
                RM:     state <= cache_inst_data_ok ? IDLE : RM;
            endcase
        end
    end

    //读内存
    //变量read_req, addr_rcv, read_finish用于构造类sram信号。
    wire read_req;      //一次完整的读事务，从发出读请求到结束
    reg addr_rcv;       //地址接收成功(addr_ok)后到结束
    wire read_finish;   //数据接收成功(data_ok)，即读请求结束
    always @(posedge clk) begin
        addr_rcv <= rst ? 1'b0 :
                    cache_inst_req & cache_inst_addr_ok ? 1'b1 :
                    read_finish ? 1'b0 : addr_rcv;
    end
    assign read_req = state==RM;
    assign read_finish = cache_inst_data_ok;

    //output to mips core
    assign cpu_inst_rdata   = hit ? c_block : cache_inst_rdata;
    assign cpu_inst_addr_ok = cpu_inst_req & hit | cache_inst_req & cache_inst_addr_ok;
    assign cpu_inst_data_ok = cpu_inst_req & hit | cache_inst_data_ok;

    //output to axi interface
    assign cache_inst_req   = read_req & ~addr_rcv;
    assign cache_inst_wr    = cpu_inst_wr;
    assign cache_inst_size  = cpu_inst_size;
    assign cache_inst_addr  = cpu_inst_addr;
    assign cache_inst_wdata = cpu_inst_wdata;

    //写入Cache
    //保存地址中的tag, index，防止addr发生改变
    reg [TAG_WIDTH-1:0] tag_save;
    reg [INDEX_WIDTH-1:0] index_save;
    reg c_lastused_save;
    reg c_currused_save;
    always @(posedge clk) begin
        tag_save        <= rst ? 0 :
                         cpu_inst_req ? tag : tag_save;
        index_save      <= rst ? 0 :
                         cpu_inst_req ? index : index_save;
        c_lastused_save <= rst ? 0 :
                         cpu_inst_req ? c_lastused : c_lastused_save;
        c_currused_save <= rst ? 0 :
                         cpu_inst_req ? c_currused : c_currused_save;
    end

    integer t;
    always @(posedge clk) begin
        if(rst) begin
            for(t=0; t<CACHE_DEEPTH; t=t+1) begin   //刚开始将Cache置为无效
                cache_valid[0][t] <= 0;
                cache_valid[1][t] <= 0;
                cache_lastused[t] <= 0;
            end
        end
        else begin
            if(read_finish) begin //读缺失，访存结束时
                cache_valid[!c_lastused_save][index_save] <= 1'b1;             //将Cache line置为有效
                cache_tag  [!c_lastused_save][index_save] <= tag_save;
                cache_block[!c_lastused_save][index_save] <= cache_inst_rdata; //写入Cache line
                cache_lastused[index_save] <= !c_lastused_save;
            end 
            else if(cpu_inst_req & hit & !no_cache) begin
                // $display("读命中"); 更新lastused
                cache_lastused[index] <= c_currused;
            end
        end
    end
endmodule