module d_cache_write_back (
    input wire clk, rst,
    //mips core
    input  wire        cpu_data_req     ,      //Mipscore�����д����  mips->cache
    input  wire        cpu_data_wr      ,       //����ǰ�����Ƿ���д����
    input  wire [1 :0] cpu_data_size    ,       //ȷ�����ݵ���Ч�ֽ�
    input  wire [31:0] cpu_data_addr    ,       // XXX �ĳ�33λ����һ��dirty
    input  wire [31:0] cpu_data_wdata   ,
    output wire [31:0] cpu_data_rdata   ,      //cache���ظ�mips������  cache->mips  �ģ�07/27 ����Ӧ����output
    output wire        cpu_data_addr_ok ,      //Cache�C>Mipscore  Cache ���ظ� Mipscore �ĵ�ַ���ֳɹ�
    output wire        cpu_data_data_ok ,

    //axi interface
    output wire        cache_data_req     ,    //Cache�C>axi_interface
                                               //Cache ���͵Ķ�д���󣬿���Ϊ cache ȱʧ�������cacheline ���滻������д����
    output wire        cache_data_wr      ,     //����ǰ�����Ƿ���д����
    output wire [1 :0] cache_data_size    ,
    output wire [31:0] cache_data_addr    ,     //�����ݵ�ַ
    output wire [31:0] cache_data_wdata   ,
    input  wire [31:0] cache_data_rdata   ,   //��mem���ظ�cache������ �ģ�07/27 ����Ӧ����input
    input  wire        cache_data_addr_ok ,   //�ɹ��յ���ַ����
    input  wire        cache_data_data_ok     //���ݳɹ�
);
//Cache����
    parameter  INDEX_WIDTH  = 10, OFFSET_WIDTH = 2;
    localparam TAG_WIDTH    = 32 - INDEX_WIDTH - OFFSET_WIDTH;
    localparam CACHE_DEEPTH = 1 << INDEX_WIDTH;
    
//Cache�洢��Ԫ
    reg                 cache_valid [CACHE_DEEPTH - 1 : 0];
    reg                 cache_dirty [CACHE_DEEPTH - 1 : 0];
    reg [TAG_WIDTH-1:0] cache_tag   [CACHE_DEEPTH - 1 : 0];
    reg [31:0]          cache_block [CACHE_DEEPTH - 1 : 0];
    
//���ʵ�ַ�ֽ�
    wire [OFFSET_WIDTH-1:0] offset;
    wire [INDEX_WIDTH-1:0] index;
    wire [TAG_WIDTH-1:0] tag;
    wire dirty;  // XXX ������λ

    assign offset = cpu_data_addr[OFFSET_WIDTH - 1 : 0];
    assign index = cpu_data_addr[INDEX_WIDTH + OFFSET_WIDTH - 1 : OFFSET_WIDTH];
    assign tag = cpu_data_addr[31 : INDEX_WIDTH + OFFSET_WIDTH];
    //assign dirty = cpu_data_addr[32:31];  // XXX 
    
//����Cache line
    wire c_valid;
    wire [TAG_WIDTH-1:0] c_tag;
    wire [31:0] c_block;
    wire c_dirty,c_dirty_save;
    assign c_dirty_save = c_dirty;             //����ԭ����dirty���ݣ�����ѭ����ֵ���´���
    assign c_valid = cache_valid[index];
    assign c_tag   = cache_tag  [index];
    assign c_block = cache_block[index];        //����
    assign c_dirty = cache_dirty[index];
    
//�ж��Ƿ�����
    wire hit, miss;
    assign hit = c_valid & (c_tag == tag);  //cache line��validλΪ1����tag���ַ��tag���
    assign miss = ~hit;

//����д
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
                IDLE:   state <= cpu_data_req & read & miss & !c_dirty ? RM :      //��ȱʧ����cache_line is clean
                                 cpu_data_req & read & miss &  c_dirty ? WM :
                                 cpu_data_req & read & hit  ? IDLE :
                                 cpu_data_req & write & miss & c_dirty ? WM : IDLE;   //дȱʧ����dirty��д�ڴ�
                RM:     state <= read  & cache_data_data_ok & hit ? IDLE : RM;   //ֻ���ڶ�miss��ʱ���Ҫ����mem
                // WM:     state <= write & cache_data_data_ok? WM : 
                //                  write & cache_data_data_ok & c_dirty? RM :     //д������ɺ�ִ�ж�����
                //                                                         IDLE ;    
                WM:     state <= write & cache_data_data_ok & c_dirty ? RM :     //д������ɺ�ִ�ж�����
                                 write & cache_data_data_ok ? IDLE : 
                                 WM;    
            endcase
        end
    end

//���ڴ�
    //����read_req, addr_rcv, read_finish���ڹ�����sram�źš�
    wire read_req;      //һ�������Ķ����񣬴ӷ��������󵽽���;��ȡ�ڴ�����
    reg  addr_rcv;      //��ַ���ճɹ�(addr_ok)�󵽽���,�����ַ�Ѿ��յ���
    wire read_finish;   //���ݽ��ճɹ�(data_ok)�������������
    always @(posedge clk) begin
        addr_rcv <= rst ? 1'b0 :
                    read & cache_data_req & cache_data_addr_ok ? 1'b1 :
                    read_finish ? 1'b0 : addr_rcv;
    end
    assign read_req = state==RM ;
    assign read_finish = read & cache_data_data_ok;

//д�ڴ� 
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
    assign cpu_data_rdata   = hit ? c_block : cache_data_rdata;  //cache ���ظ�mips������
    assign cpu_data_addr_ok = read & cpu_data_req & hit | cache_data_req & cache_data_addr_ok;
    assign cpu_data_data_ok = read & cpu_data_req & hit | cache_data_data_ok;

//output to axi interface
    assign cache_data_req   = read_req & ~addr_rcv | write_req & ~waddr_rcv;
    assign cache_data_wr    = cpu_data_wr;
    assign cache_data_size  = cpu_data_size;
    assign cache_data_addr  = cpu_data_addr;
    assign cache_data_wdata = read & miss & c_dirty_save ? c_block : cpu_data_wdata;
    
//д��Cache
    //�����ַ�е�tag, index����ֹaddr�����ı�
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

    //���ݵ�ַ����λ��size������д���루���sb��sh�Ȳ���д����һ���ֵ�ָ���4λ��Ӧ1���֣�4�ֽڣ���ÿ���ֵ�дʹ��
    assign write_mask = cpu_data_size==2'b00 ?
                            (cpu_data_addr[1] ? (cpu_data_addr[0] ? 4'b1000 : 4'b0100):
                                                (cpu_data_addr[0] ? 4'b0010 : 4'b0001)) :
                            (cpu_data_size==2'b01 ? (cpu_data_addr[1] ? 4'b1100 : 4'b0011) : 4'b1111);

    //�����ʹ�ã�λΪ1�Ĵ�����Ҫ���µġ�
    //λ��չ��{8{1'b1}} -> 8'b11111111
    //new_data = old_data & ~mask | write_data & mask
    assign write_cache_data = cache_block[index] & ~{{8{write_mask[3]}}, {8{write_mask[2]}}, {8{write_mask[1]}}, {8{write_mask[0]}}} | 
                              cpu_data_wdata & {{8{write_mask[3]}}, {8{write_mask[2]}}, {8{write_mask[1]}}, {8{write_mask[0]}}};

    integer t;
    always @(posedge clk) begin
        if(rst) begin
            for(t=0; t<CACHE_DEEPTH; t=t+1) begin   //�տ�ʼ��Cache��Ϊ��Ч
                cache_valid[t] <= 0;
                cache_dirty[t] <= 0; 
            end
        end
        //TODO ��Щdirtyɶ�Ļ����Ǻ�ȷ����˵����һ
        else begin
            if(read_finish) begin //��ȱʧ���ô����ʱ
                cache_valid[index_save] <= 1'b1;             //��Cache line��Ϊ��Ч
                cache_tag  [index_save] <= tag_save;
                cache_block[index_save] <= cache_data_rdata; //д��Cache line
                // cache_dirty[index_save] <= 1'b0;
            end
            else if(read & cpu_data_req & miss) begin   //��ȱʧҲ��ҪдCache
                cache_block[index] <= write_cache_data;      //д��Cache line��ʹ��index������index_save
                cache_dirty[index] <= 1'b0;                 //dirty��0
            end
            else if(write & cpu_data_req & hit) begin   //д����ʱ��ҪдCache
                cache_block[index] <= write_cache_data;      //д��Cache line��ʹ��index������index_save
                cache_dirty[index] <= 1'b1;                 //д����ʱ��Ҫ����λ��Ϊ1
            end
            else if(write & cpu_data_req & miss & !c_dirty) begin   //дȱʧ��cachelineΪclean
                cache_block[index] <= write_cache_data;     
                cache_dirty[index] <= 1'b1;                 
            end
        end
    end
    // assign c_dirty= (cpu_data_req & read & miss  & c_dirty_save)?  1'b0 :       //��ȱʧ��Ϊ���ʱ��������Ϊ0
    //                 (cpu_data_req & write & hit  & !c_dirty_save)? 1'b1 :       //д���е�ʱ��ԭ��ΪcleanҪ��������Ϊdirty
    //                 (cpu_data_req & write & miss & c_dirty_save)?  1'b1 :       //дȱʧ��ʱ��ԭ��Ϊ��Ļ����ڻ���ҪΪ��
    //                                                        c_dirty_save ;
endmodule