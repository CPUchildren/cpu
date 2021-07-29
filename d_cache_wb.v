module d_cache_write_back (
    input wire clk, rst,
    //mips core
    input  wire        cpu_data_req     ,      //Mipscore发起读写请求  mips->cache
    input  wire        cpu_data_wr      ,       //代表当前请求是否是写请求
    input  wire [1 :0] cpu_data_size    ,       //确定数据的有效字节
    input  wire [31:0] cpu_data_addr    ,       // XXX 改成33位，加一个dirty
    input  wire [31:0] cpu_data_wdata   ,
    output wire [31:0] cpu_data_rdata   ,      //cache返回给mips的数据  cache->mips  改：07/27 这里应该是output
    output wire        cpu_data_addr_ok ,      //Cache–>Mipscore  Cache 返回给 Mipscore 的地址握手成功
    output wire        cpu_data_data_ok ,

    //axi interface
    output wire        cache_data_req     ,    //Cache–>axi_interface
                                               //Cache 发送的读写请求，可因为 cache 缺失或者脏的cacheline 被替换产生的写请求
    output wire        cache_data_wr      ,     //代表当前请求是否是写请求
    output wire [1 :0] cache_data_size    ,
    output wire [31:0] cache_data_addr    ,     //读数据地址
    output wire [31:0] cache_data_wdata   ,
    input  wire [31:0] cache_data_rdata   ,   //从mem返回给cache的数据 改：07/27 这里应该是input
    input  wire        cache_data_addr_ok ,   //成功收到地址数据
    input  wire        cache_data_data_ok     //数据成功
);
//Cache配置
    parameter  INDEX_WIDTH  = 10, OFFSET_WIDTH = 2;
    localparam TAG_WIDTH    = 32 - INDEX_WIDTH - OFFSET_WIDTH;
    localparam CACHE_DEEPTH = 1 << INDEX_WIDTH;
    
//Cache存储单元
    reg                 cache_valid [CACHE_DEEPTH - 1 : 0];
    reg                 cache_dirty [CACHE_DEEPTH - 1 : 0];
    reg [TAG_WIDTH-1:0] cache_tag   [CACHE_DEEPTH - 1 : 0];
    reg [31:0]          cache_block [CACHE_DEEPTH - 1 : 0];
    
//访问地址分解
    wire [OFFSET_WIDTH-1:0] offset;
    wire [INDEX_WIDTH-1:0] index;
    wire [TAG_WIDTH-1:0] tag;
    wire dirty;  // XXX 设置脏位

    assign offset = cpu_data_addr[OFFSET_WIDTH - 1 : 0];
    assign index = cpu_data_addr[INDEX_WIDTH + OFFSET_WIDTH - 1 : OFFSET_WIDTH];
    assign tag = cpu_data_addr[31 : INDEX_WIDTH + OFFSET_WIDTH];
    //assign dirty = cpu_data_addr[32:31];  // XXX 
    
//访问Cache line
    wire c_valid;
    wire [TAG_WIDTH-1:0] c_tag;
    wire [31:0] c_block;
    wire c_dirty,c_dirty_save;
    assign c_dirty_save = c_dirty;             //保存原来的dirty数据，避免循环赋值导致错误
    assign c_valid = cache_valid[index];
    assign c_tag   = cache_tag  [index];
    assign c_block = cache_block[index];        //数据
    assign c_dirty = cache_dirty[index];
    
//判断是否命中
    wire hit, miss;
    assign hit = c_valid & (c_tag == tag);  //cache line的valid位为1，且tag与地址中tag相等
    assign miss = ~hit;

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
                IDLE:   state <= cpu_data_req & read & miss & !c_dirty ? RM :      //读缺失并且cache_line is clean
                                 cpu_data_req & read & miss &  c_dirty ? WM :
                                 cpu_data_req & read & hit  ? IDLE :
                                 cpu_data_req & write & miss & c_dirty ? WM : IDLE;   //写缺失并且dirty才写内存
                RM:     state <= read  & cache_data_data_ok & hit ? IDLE : RM;   //只有在读miss的时候才要访问mem
                // WM:     state <= write & cache_data_data_ok? WM : 
                //                  write & cache_data_data_ok & c_dirty? RM :     //写请求完成后执行读请求
                //                                                         IDLE ;    
                WM:     state <= write & cache_data_data_ok & c_dirty ? RM :     //写请求完成后执行读请求
                                 write & cache_data_data_ok ? IDLE : 
                                 WM;    
            endcase
        end
    end

//读内存
    //变量read_req, addr_rcv, read_finish用于构造类sram信号。
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

//写内存 
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
    assign cpu_data_rdata   = hit ? c_block : cache_data_rdata;  //cache 返回给mips的数据
    assign cpu_data_addr_ok = read & cpu_data_req & hit | cache_data_req & cache_data_addr_ok;
    assign cpu_data_data_ok = read & cpu_data_req & hit | cache_data_data_ok;

//output to axi interface
    assign cache_data_req   = read_req & ~addr_rcv | write_req & ~waddr_rcv;
    assign cache_data_wr    = cpu_data_wr;
    assign cache_data_size  = cpu_data_size;
    assign cache_data_addr  = cpu_data_addr;
    assign cache_data_wdata = read & miss & c_dirty_save ? c_block : cpu_data_wdata;
    
//写入Cache
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
    wire [3:0] write_mask;

    //根据地址低两位和size，生成写掩码（针对sb，sh等不是写完整一个字的指令），4位对应1个字（4字节）中每个字的写使能
    assign write_mask = cpu_data_size==2'b00 ?
                            (cpu_data_addr[1] ? (cpu_data_addr[0] ? 4'b1000 : 4'b0100):
                                                (cpu_data_addr[0] ? 4'b0010 : 4'b0001)) :
                            (cpu_data_size==2'b01 ? (cpu_data_addr[1] ? 4'b1100 : 4'b0011) : 4'b1111);

    //掩码的使用：位为1的代表需要更新的。
    //位拓展：{8{1'b1}} -> 8'b11111111
    //new_data = old_data & ~mask | write_data & mask
    assign write_cache_data = cache_block[index] & ~{{8{write_mask[3]}}, {8{write_mask[2]}}, {8{write_mask[1]}}, {8{write_mask[0]}}} | 
                              cpu_data_wdata & {{8{write_mask[3]}}, {8{write_mask[2]}}, {8{write_mask[1]}}, {8{write_mask[0]}}};

    integer t;
    always @(posedge clk) begin
        if(rst) begin
            for(t=0; t<CACHE_DEEPTH; t=t+1) begin   //刚开始将Cache置为无效
                cache_valid[t] <= 0;
                cache_dirty[t] <= 0; 
            end
        end
        //TODO 这些dirty啥的还不是很确定，说法不一
        else begin
            if(read_finish) begin //读缺失，访存结束时
                cache_valid[index_save] <= 1'b1;             //将Cache line置为有效
                cache_tag  [index_save] <= tag_save;
                cache_block[index_save] <= cache_data_rdata; //写入Cache line
                // cache_dirty[index_save] <= 1'b0;
            end
            else if(read & cpu_data_req & miss) begin   //读缺失也需要写Cache
                cache_block[index] <= write_cache_data;      //写入Cache line，使用index而不是index_save
                cache_dirty[index] <= 1'b0;                 //dirty置0
            end
            else if(write & cpu_data_req & hit) begin   //写命中时需要写Cache
                cache_block[index] <= write_cache_data;      //写入Cache line，使用index而不是index_save
                cache_dirty[index] <= 1'b1;                 //写命中时需要将脏位置为1
            end
            else if(write & cpu_data_req & miss & !c_dirty) begin   //写缺失且cacheline为clean
                cache_block[index] <= write_cache_data;     
                cache_dirty[index] <= 1'b1;                 
            end
        end
    end
    // assign c_dirty= (cpu_data_req & read & miss  & c_dirty_save)?  1'b0 :       //读缺失且为脏的时候将其设置为0
    //                 (cpu_data_req & write & hit  & !c_dirty_save)? 1'b1 :       //写命中的时候原来为clean要将其设置为dirty
    //                 (cpu_data_req & write & miss & c_dirty_save)?  1'b1 :       //写缺失的时候原来为脏的话现在还是要为脏
    //                                                        c_dirty_save ;
endmodule