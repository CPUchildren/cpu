module d_cache_2way (
    input wire clk, rst,
    // mips core 
    // input : mipscore -> cache 
    // output: cahce    -> mipscore
    input  wire        cpu_data_req     ,      //Mipscore�����д����  mips->cache
    input  wire        cpu_data_wr      ,      //����ǰ�����Ƿ���д����
    input  wire [1 :0] cpu_data_size    ,      //ȷ�����ݵ���Ч�ֽ�
    input  wire [31:0] cpu_data_addr    ,      
    input  wire [31:0] cpu_data_wdata   ,
    output wire [31:0] cpu_data_rdata   ,      //cache���ظ�mips������  cache->mips  �ģ�07/27 ����Ӧ����output
    output wire        cpu_data_addr_ok ,      //Cache�C>Mipscore  Cache ���ظ� Mipscore �ĵ�ַ���ֳɹ�
    output wire        cpu_data_data_ok ,

    // axi interface
    // input : axi_interface -> cache
    // output: cache         -> axi_interface
    output wire        cache_data_req     ,    //Cache ���͵Ķ�д���󣬿���Ϊ cache ȱʧ�������cacheline ���滻������д����
    output wire        cache_data_wr      ,    //����ǰ�����Ƿ���д����
    output wire [1 :0] cache_data_size    ,
    output wire [31:0] cache_data_addr    ,    //�����ݵ�ַ
    output wire [31:0] cache_data_wdata   ,
    input  wire [31:0] cache_data_rdata   ,    //��mem���ظ�cache������ �ģ�07/27 ����Ӧ����input
    input  wire        cache_data_addr_ok ,    //�ɹ��յ���ַ����
    input  wire        cache_data_data_ok       //���ݳɹ�
);
//Cache��������
    // cache��������Ϊ4MB����ʱ������һ·��indec_width��1
    parameter  INDEX_WIDTH  = 9, OFFSET_WIDTH = 2, WAY_NUM = 2; 
    localparam TAG_WIDTH    = 32 - INDEX_WIDTH - OFFSET_WIDTH;
    localparam CACHE_DEEPTH = 1 << INDEX_WIDTH;
    
//Cache�洢��Ԫ
    reg                 cache_lastused[CACHE_DEEPTH - 1 : 0]; // ÿ��cache����1bit lastused��־��0:way1,1:way2
    reg                 cache_valid   [WAY_NUM-1 : 0][CACHE_DEEPTH - 1 : 0];
    reg [TAG_WIDTH-1:0] cache_tag     [WAY_NUM-1 : 0][CACHE_DEEPTH - 1 : 0];
    reg [31:0]          cache_block   [WAY_NUM-1 : 0][CACHE_DEEPTH - 1 : 0];
    
//���ʵ�ַ�ֽ�
    wire [OFFSET_WIDTH-1:0] offset;
    wire [INDEX_WIDTH-1:0] index;
    wire [TAG_WIDTH-1:0] tag;

    assign offset = cpu_data_addr[OFFSET_WIDTH - 1 : 0];
    assign index = cpu_data_addr[INDEX_WIDTH + OFFSET_WIDTH - 1 : OFFSET_WIDTH];
    assign tag = cpu_data_addr[31 : INDEX_WIDTH + OFFSET_WIDTH];
    
//����Cache Line�����ж��Ƿ�����
    reg c_valid, hit, miss;
    reg [TAG_WIDTH-1:0] c_tag;
    reg [31:0] c_block;
    integer c_way;  // XXX �������Ͳ�ȷ��
    integer t2;
    always @(*) begin
        c_way   <= 32'b0;
        c_valid <= cache_valid[0][index];
        c_tag   <= cache_tag  [0][index];
        c_block <= cache_block[0][index];
        hit     <= 1'b0;
        miss    <= 1'b1;
        // ʵ�ַ�ʽһ��ѭ��ʵ��
        for(t2=0; t2<WAY_NUM; t2=t2+1) begin   //�տ�ʼ��Cache��Ϊ��Ч
            if(cache_tag[t2][index] == tag) begin
                c_way   <= t2;
                c_valid <=  cache_valid[t2][index];
                c_tag   <=  cache_tag  [t2][index];
                c_block <=  cache_block[t2][index];
                hit     <=  cache_valid[t2][index];
                miss    <= ~cache_valid[t2][index];
            end
        end
        // TODO ʵ�ַ�ʽ�����������ͽ���������·ͼ����
    end

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
                IDLE:   state <= cpu_data_req & read & miss ? RM :      //��ȱʧ����cache_line is clean
                                 cpu_data_req & read & hit  ? IDLE :
                                 cpu_data_req & write       ? WM : IDLE;
                RM:     state <= read & cache_data_data_ok & hit ? IDLE : RM;   //ֻ���ڶ�miss��ʱ���Ҫ����mem
                WM:     state <= write & cache_data_data_ok? IDLE : WM ;
            endcase
        end
    end

//���ڴ棬RM�źŴ���
    //����read_req, addr_rcv, read_finish���ڹ�����sram�źš�
    // TODO ����ֱ�ӹ���axi_interface�ź�
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

//д�ڴ棬WM�źŴ���
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
    
// д��Cache
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
    wire [3 :0] write_mask4;
    wire [31:0] write_mask32;

    //���ݵ�ַ����λ��size������д���루���sb��sh�Ȳ���д����һ���ֵ�ָ���4λ��Ӧ1���֣�4�ֽڣ���ÿ���ֵ�дʹ��
    assign write_mask4 = cpu_data_size==2'b00 ?
                            cpu_data_addr[1] ? (cpu_data_addr[0] ? 4'b1000 : 4'b0100) :  // 00->11,10
                                               (cpu_data_addr[0] ? 4'b0010 : 4'b0001) :  // 00->01,00
                        cpu_data_size==2'b01 ? (cpu_data_addr[1] ? 4'b1100 : 4'b0011) :  // 01->10,00
                        4'b1111; // 10->00

    //�����ʹ�ã�λΪ1�Ĵ�����Ҫ���µġ�
    //λ��չ��{8{1'b1}} -> 8'b11111111
    assign write_mask32 = { {8{write_mask4[3]}}, {8{write_mask4[2]}}, {8{write_mask4[1]}}, {8{write_mask4[0]}} };
    assign write_cache_data = cache_block[c_way][index] & ~write_mask32 | cpu_data_wdata & write_mask32; // Ĭ��ԭ���ݣ���д������д�����������

// Cache�ڲ�����ά�������λʵ���滻�㷨
    integer t1;
    always @(posedge clk) begin
        if(rst) begin
            for(t1=0; t1<CACHE_DEEPTH; t1=t1+1) begin   //�տ�ʼ��Cache��Ϊ��Ч
                cache_valid[0][t1] <= 0;
                cache_valid[1][t1] <= 0;
                cache_lastused[t1] <= 0;  // ��ʼ��0·Ϊlastused
            end
        end
        else begin
            if(read_finish) begin //���ڴ�ô����ʱ
               // �滻ԭ����Ҫѡ��һ��
                if(cache_lastused[index_save]) begin                   // �ϴη��ʵ�1·
                    cache_lastused[index_save] <= 0;
                    cache_valid   [0][index_save] <= 1'b1;             //��Cache line��Ϊ��Ч
                    cache_tag     [0][index_save] <= tag_save;
                    cache_block   [0][index_save] <= cache_data_rdata; //д��Cache line
                end else begin                                         // �ϴη��ʵ�0·
                    cache_lastused[index_save] <= 1;
                    cache_valid   [1][index_save] <= 1'b1;             //��Cache line��Ϊ��Ч
                    cache_tag     [1][index_save] <= tag_save;
                    cache_block   [1][index_save] <= cache_data_rdata; //д��Cache line
                end
            end
            else if(write & cpu_data_req & hit) begin   //д����ʱ��ҪдCache
                // TODO ����c_way��Ҫsave��
                cache_block[c_way][index] <= write_cache_data;      //д��Cache line��ʹ��index������index_save
            end
        end
    end
   
endmodule