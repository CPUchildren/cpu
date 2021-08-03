module d_cache_2way (
    input wire clk, rst,
    // mips core 
    // input : mipscore -> cache 
    // output: cahce    -> mipscore
    input  wire        cpu_data_req     ,      //Mipscore发起读写请求  mips->cache
    input  wire        cpu_data_wr      ,      //代表当前请求是否是写请求
    input  wire [1 :0] cpu_data_size    ,      //确定数据的有效字节
    input  wire [31:0] cpu_data_addr    ,      
    input  wire [31:0] cpu_data_wdata   ,
    output wire [31:0] cpu_data_rdata   ,      //cache返回给mips的数据  cache->mips  改：07/27 这里应该是output
    output wire        cpu_data_addr_ok ,      //Cache–>Mipscore  Cache 返回给 Mipscore 的地址握手成功
    output wire        cpu_data_data_ok ,

    // axi interface
    // input : axi_interface -> cache
    // output: cache         -> axi_interface
    output wire        cache_data_req     ,    //Cache 发送的读写请求，可因为 cache 缺失或者脏的cacheline 被替换产生的写请求
    output wire        cache_data_wr      ,    //代表当前请求是否是写请求
    output wire [1 :0] cache_data_size    ,
    output wire [31:0] cache_data_addr    ,    //读数据地址
    output wire [31:0] cache_data_wdata   ,
    input  wire [31:0] cache_data_rdata   ,    //从mem返回给cache的数据 改：07/27 这里应该是input
    input  wire        cache_data_addr_ok ,    //成功收到地址数据
    input  wire        cache_data_data_ok       //数据成功
);
//Cache参数配置
    // cache数据容量为4MB不变时，增加一路，indec_width少1
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

    assign offset = cpu_data_addr[OFFSET_WIDTH - 1 : 0];
    assign index = cpu_data_addr[INDEX_WIDTH + OFFSET_WIDTH - 1 : OFFSET_WIDTH];
    assign tag = cpu_data_addr[31 : INDEX_WIDTH + OFFSET_WIDTH];
    
//访问Cache Line，并判断是否命中
    reg c_valid, hit, miss;
    reg [TAG_WIDTH-1:0] c_tag;
    reg [31:0] c_block;
    integer c_way;  // XXX 参数类型不确定
    integer t2;
    always @(*) begin
        c_way   <= 32'b0;
        c_valid <= cache_valid[0][index];
        c_tag   <= cache_tag  [0][index];
        c_block <= cache_block[0][index];
        hit     <= 1'b0;
        miss    <= 1'b1;
        // 实现方式一：循环实现
        for(t2=0; t2<WAY_NUM; t2=t2+1) begin   //刚开始将Cache置为无效
            if(cache_tag[t2][index] == tag) begin
                c_way   <= t2;
                c_valid <=  cache_valid[t2][index];
                c_tag   <=  cache_tag  [t2][index];
                c_block <=  cache_block[t2][index];
                hit     <=  cache_valid[t2][index];
                miss    <= ~cache_valid[t2][index];
            end
        end
        // TODO 实现方式二：译码器和解码器，电路图见书
    end

//读或写
    wire read, write;
    assign write = cpu_data_wr;
    assign read = ~write;

//FSM
    parameter IDLE = 2'b00, RM = 2'b01, WM = 2'b11;
    reg [1:0] state;
    always @(posedge clk) begin
        if(rst) begin
            state <= IDLE;
        end
        else begin
            case(state)
                IDLE:   state <= cpu_data_req & read & miss ? RM :      //读缺失并且cache_line is clean
                                 cpu_data_req & read & hit  ? IDLE :
                                 cpu_data_req & write       ? WM : IDLE;
                RM:     state <= read & cache_data_data_ok & hit ? IDLE : RM;   //只有在读miss的时候才要访问mem
                WM:     state <= write & cache_data_data_ok? IDLE : WM ;
            endcase
        end
    end

//读内存，RM信号传输
    //变量read_req, addr_rcv, read_finish用于构造类sram信号。
    // TODO 可以直接构造axi_interface信号
    wire read_req;      //一次完整的读事务，从发出读请求到结束;读取内存请求
    reg  addr_rcv;      //地址接收成功(addr_ok)后到结束,代表地址已经收到了
    wire read_finish;   //数据接收成功(data_ok)，即读请求结束
    always @(posedge clk) begin
        addr_rcv <= rst ? 1'b0 :
                    read & cache_data_req & cache_data_addr_ok ? 1'b1 :
                    read_finish ? 1'b0 : addr_rcv;
    end
    assign read_req = state==RM ;
    assign read_finish = read & cache_data_data_ok;

//写内存，WM信号传输
    wire write_req;     
    reg  waddr_rcv;      
    wire write_finish;   
    always @(posedge clk) begin
        waddr_rcv <= rst ? 1'b0 :
                     write & cache_data_req & cache_data_addr_ok ? 1'b1 :
                     write_finish ? 1'b0 : waddr_rcv;
    end

    assign write_req = state==WM;
    assign write_finish = write & cache_data_data_ok;
    
//output to mips core
    assign cpu_data_rdata   = hit ? c_block : cache_data_rdata;
    assign cpu_data_addr_ok = read & cpu_data_req & hit | cache_data_req & cache_data_addr_ok;
    assign cpu_data_data_ok = read & cpu_data_req & hit | cache_data_data_ok;

//output to axi interface
    assign cache_data_req   = read_req & ~addr_rcv | write_req & ~waddr_rcv;
    assign cache_data_wr    = cpu_data_wr;
    assign cache_data_size  = cpu_data_size;
    assign cache_data_addr  = cpu_data_addr;
    assign cache_data_wdata = cpu_data_wdata;
    
// 写入Cache
    //保存地址中的tag, index，防止addr发生改变
    reg [TAG_WIDTH-1:0] tag_save;
    reg [INDEX_WIDTH-1:0] index_save;
    always @(posedge clk) begin
        tag_save   <= rst ? 0 :
                      cpu_data_req ? tag : tag_save;
        index_save <= rst ? 0 :
                      cpu_data_req ? index : index_save;
    end

    wire [31:0] write_cache_data;
    wire [3 :0] write_mask4;
    wire [31:0] write_mask32;

    //根据地址低两位和size，生成写掩码（针对sb，sh等不是写完整一个字的指令），4位对应1个字（4字节）中每个字的写使能
    assign write_mask4 = cpu_data_size==2'b00 ?
                            cpu_data_addr[1] ? (cpu_data_addr[0] ? 4'b1000 : 4'b0100) :  // 00->11,10
                                               (cpu_data_addr[0] ? 4'b0010 : 4'b0001) :  // 00->01,00
                        cpu_data_size==2'b01 ? (cpu_data_addr[1] ? 4'b1100 : 4'b0011) :  // 01->10,00
                        4'b1111; // 10->00

    //掩码的使用：位为1的代表需要更新的。
    //位拓展：{8{1'b1}} -> 8'b11111111
    assign write_mask32 = { {8{write_mask4[3]}}, {8{write_mask4[2]}}, {8{write_mask4[1]}}, {8{write_mask4[0]}} };
    assign write_cache_data = cache_block[c_way][index] & ~write_mask32 | cpu_data_wdata & write_mask32; // 默认原数据，有写请求再写入读到的数据

// Cache内部数据维护，标记位实现替换算法
    integer t1;
    always @(posedge clk) begin
        if(rst) begin
            for(t1=0; t1<CACHE_DEEPTH; t1=t1+1) begin   //刚开始将Cache置为无效
                cache_valid[0][t1] <= 0;
                cache_valid[1][t1] <= 0;
                cache_lastused[t1] <= 0;  // 初始化0路为lastused
            end
        end
        else begin
            if(read_finish) begin //读内存访存结束时
               // 替换原则，需要选择一个
                if(cache_lastused[index_save]) begin                   // 上次访问的1路
                    cache_lastused[index_save] <= 0;
                    cache_valid   [0][index_save] <= 1'b1;             //将Cache line置为有效
                    cache_tag     [0][index_save] <= tag_save;
                    cache_block   [0][index_save] <= cache_data_rdata; //写入Cache line
                end else begin                                         // 上次访问的0路
                    cache_lastused[index_save] <= 1;
                    cache_valid   [1][index_save] <= 1'b1;             //将Cache line置为有效
                    cache_tag     [1][index_save] <= tag_save;
                    cache_block   [1][index_save] <= cache_data_rdata; //写入Cache line
                end
            end
            else if(write & cpu_data_req & hit) begin   //写命中时需要写Cache
                // TODO 这里c_way需要save吗？
                cache_block[c_way][index] <= write_cache_data;      //写入Cache line，使用index而不是index_save
            end
        end
    end
   
endmodule