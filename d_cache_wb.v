module d_cache_wb (
    input wire clk, rst,except,no_cache,
    //mips core
    input  wire        cpu_data_req     ,      //Mipscore发起读写请求  mips->cache
    input  wire        cpu_data_wr      ,       //代表当前请求是否是写请求
    input  wire [1 :0] cpu_data_size    ,       //确定数据的有效字节
    input  wire [31:0] cpu_data_addr    ,       
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

    assign offset = cpu_data_addr[OFFSET_WIDTH - 1 : 0];
    assign index = cpu_data_addr[INDEX_WIDTH + OFFSET_WIDTH - 1 : OFFSET_WIDTH];
    assign tag = cpu_data_addr[31 : INDEX_WIDTH + OFFSET_WIDTH];
    
//访问Cache line
    wire c_valid;
    wire [TAG_WIDTH-1:0] c_tag;
    wire [31:0] c_block;
    wire c_dirty;
    assign c_valid = cache_valid[index];
    assign c_tag   = cache_tag  [index];
    assign c_block = cache_block[index];        //数据
    assign c_dirty = cache_dirty[index];
    
//判断是否命中
    wire hit, miss;
    assign hit  = !no_cache & cpu_data_req &c_valid & (c_tag == tag);  //cache line的valid位为1，且tag与地址中tag相等
    assign miss = !no_cache & cpu_data_req & ~hit;

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
                IDLE:   state <= cpu_data_req & read & no_cache ? RM :
                                 cpu_data_req & write & no_cache ? WM :
                                 cpu_data_req & read & miss & !c_dirty & !except ? RM :         // 读缺失且该位没有被修改
                                 cpu_data_req & read & miss &  c_dirty & !except ? WM :         // 读缺失且该位修改过
                                 cpu_data_req & read & hit  ? IDLE :                            // 读命中
                                 cpu_data_req & write & miss & c_dirty & !except & !write_miss_nodirty_save ? WM : IDLE;   // 写缺失并且dirty才写内存
                RM:     state <= read  & cache_data_data_ok ? IDLE : RM;
                WM:     state <= read & cache_data_data_ok & c_dirty ? RM :     // 读请求下写存完毕后读存
                                 write & cache_data_data_ok ? IDLE :            // 写请求下写存完毕
                                 WM;    
            endcase
        end
    end

//读内存
    //变量read_req, addr_rcv, read_finish用于构造类sram信号。
    wire read_req;      //一次完整的读事务，从发出读请求到结束;读取内存请求
    reg  addr_rcv;      //地址接收成功(addr_ok)后到结束,代表地址已经收到了
    wire read_finish;   //数据接收成功(data_ok)，即读请求结束
    assign read_req = state==RM ;
    assign read_finish = read & cache_data_data_ok;
    always @(posedge clk) begin
        addr_rcv <= rst ? 1'b0 :
                    read & cache_data_req & cache_data_addr_ok ? 1'b1 :
                    read_finish ? 1'b0 : addr_rcv;
    end

//写内存 
    wire write_req;     
    reg  waddr_rcv;      
    wire write_finish;
    assign write_req = state==WM;
    assign write_finish = write & cache_data_data_ok;
    always @(posedge clk) begin
        waddr_rcv <= rst ? 1'b0 :
                     write & cache_data_req & cache_data_addr_ok ? 1'b1 :
                     write_finish ? 1'b0 : waddr_rcv;
    end
    
//output to mips core
    // 这里涉及状态交互需要一个clk，所以需要一个reg来延迟一个clk，避免因为中间时延发生IDLE-->WM
    reg write_miss_nodirty_save; // 写缺失写干净信号添加，且为缓存状态
    wire no_mem;                 // 无需访存信号==>直接握手成功   
    always @(posedge clk) begin
        if(rst) write_miss_nodirty_save <= 1'b0;
        else if (write & miss & !c_dirty & !no_cache) write_miss_nodirty_save <= 1'b1;
        else write_miss_nodirty_save <= 1'b0;
    end
    assign no_mem = (read & cpu_data_req & hit) |                // 读命中，无需访存
                    (write & cpu_data_req & hit & !no_cache) |   // 写命中，无需访存
                    write_miss_nodirty_save;                     // 写缺失写干净，无需访存
    assign cpu_data_rdata   = hit ? c_block : cache_data_rdata;  //cache 返回给mips的数据
    assign cpu_data_addr_ok = no_mem | (cache_data_req & cache_data_addr_ok);
    assign cpu_data_data_ok = no_mem | (cache_data_data_ok);
                               

//output to axi interface
    assign cache_data_req   = read_req & ~addr_rcv | write_req & ~waddr_rcv;
    assign cache_data_wr    = ((state==IDLE) & miss & c_dirty) ? 1'b1 : cpu_data_wr;
    assign cache_data_size  = ((state==IDLE) & miss & c_dirty) ? 2'b10: cpu_data_size;
    assign cache_data_addr  = ((state==IDLE) & miss & c_dirty) ? {c_tag,index,2'b00} : cpu_data_addr;
    assign cache_data_wdata = ((state==IDLE) & miss & c_dirty) ? c_block : cpu_data_wdata;
    // 另一种写法，但是需要reg状态
    // always @(*) begin
    //     if((state==IDLE) & cpu_data_req & miss & c_dirty) begin
    //         cache_data_wr    <= 1'b1;
    //         cache_data_size  <= 2'b10;
    //         cache_data_addr  <= {c_tag,index,2'b00};
    //         cache_data_wdata <= c_block;
    //     end else begin
    //         cache_data_wr    = cpu_data_wr;
    //         cache_data_size  = cpu_data_size;
    //         cache_data_addr  = cpu_data_addr;
    //         cache_data_wdata = cpu_data_wdata;
    //     end
    // end

//写入Cache
    //保存地址中的tag, index，防止addr发生改变
    reg [TAG_WIDTH-1:0] tag_save;
    reg [INDEX_WIDTH-1:0] index_save;
    always @(posedge clk) begin
        tag_save     <= rst ? 0 :
                      cpu_data_req ? tag : tag_save;
        index_save   <= rst ? 0 :
                      cpu_data_req ? index : index_save;
    end

    // 通过掩码确认写入的数据
    wire [31:0] write_cache_data;
    wire [3:0] write_mask4;
    wire [31:0] write_mask32;
    //根据地址低两位和size，生成写掩码（针对sb，sh等不是写完整一个字的指令），4位对应1个字（4字节）中每个字的写使能
    assign write_mask4 = cpu_data_size==2'b00 ?
                            (cpu_data_addr[1] ? (cpu_data_addr[0] ? 4'b1000 : 4'b0100):
                                                (cpu_data_addr[0] ? 4'b0010 : 4'b0001)) :
                            (cpu_data_size==2'b01 ? (cpu_data_addr[1] ? 4'b1100 : 4'b0011) : 4'b1111);
    //掩码的使用：位为1的代表需要更新的。
    //位拓展：{8{1'b1}} -> 8'b11111111
    //new_data = old_data & ~mask | write_data & mask
    assign write_mask32 = { {8{write_mask4[3]}}, {8{write_mask4[2]}}, {8{write_mask4[1]}}, {8{write_mask4[0]}} };
    assign write_cache_data = cache_block[index] & ~write_mask32 | cpu_data_wdata & write_mask32; // 默认原数据，有写请求再写入读到的数据

    // 写cache
    integer t;
    always @(posedge clk) begin
        if(rst) begin
            for(t=0; t<CACHE_DEEPTH; t=t+1) begin   //刚开始将Cache置为无效
                cache_valid[t] <= 0;
                cache_dirty[t] <= 0; 
            end
        end
        else begin
            if(read_finish & !no_cache) begin  // 读缺失，读存结束
                // $display("读缺失读存结束");
                cache_valid[index_save] <= 1'b1;             //将Cache line置为有效
                cache_tag  [index_save] <= tag_save;
                cache_block[index_save] <= cache_data_rdata; //写入Cache line
                cache_dirty[index_save] <= 1'b0;
            end
            else if(write & cpu_data_req & hit & !no_cache) begin   // 写命中时需要写Cache
                // $display("写命中");
                cache_block[index] <= write_cache_data;             // 写入Cache line，使用index而不是index_save
                cache_dirty[index] <= 1'b1;                         // 写命中时需要将脏位置为1
            end
            else if(write & (state==WM) & cache_data_data_ok & !no_cache) begin   // 写缺失会有一个写存，地址握手成功后cpu_data_req会拉下来
                // $display("写缺失写脏");
                cache_block[index] <= write_cache_data;     
                cache_dirty[index] <= 1'b1;                 
            end 
            else if(write & (state==IDLE) & write_miss_nodirty_save) begin   // 写缺失+干净后的直接写操作
                // $display("写缺失写干净");
                cache_valid[index_save] <= 1'b1;             //将Cache line置为有效
                cache_tag  [index_save] <= tag_save;
                cache_block[index_save] <= cpu_data_wdata;
                cache_dirty[index_save] <= 1'b1;                 
            end
        end
    end
endmodule