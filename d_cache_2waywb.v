module d_cache_2waywb (
    input wire clk, rst,except,no_cache,
    //mips core
    input  wire        cpu_data_req     ,      //Mipscore�����д����  mips->cache
    input  wire        cpu_data_wr      ,       //����ǰ�����Ƿ���д����
    input  wire [1 :0] cpu_data_size    ,       //ȷ�����ݵ���Ч�ֽ�
    input  wire [31:0] cpu_data_addr    ,       
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
    // cache��������Ϊ4MB����ʱ������һ·��indec_width��1��tagλ��1
    parameter  INDEX_WIDTH  = 9, OFFSET_WIDTH = 2, WAY_NUM = 2; 
    localparam TAG_WIDTH    = 32 - INDEX_WIDTH - OFFSET_WIDTH;
    localparam CACHE_DEEPTH = 1 << INDEX_WIDTH;
    
//Cache�洢��Ԫ
    reg                 cache_lastused[CACHE_DEEPTH - 1 : 0]; // ÿ��cache����1bit lastused��־��0:way1,1:way2
    reg                 cache_valid   [WAY_NUM-1 : 0][CACHE_DEEPTH - 1 : 0];
    reg                 cache_dirty   [WAY_NUM-1 : 0][CACHE_DEEPTH - 1 : 0];
    reg [TAG_WIDTH-1:0] cache_tag     [WAY_NUM-1 : 0][CACHE_DEEPTH - 1 : 0];
    reg [31:0]          cache_block   [WAY_NUM-1 : 0][CACHE_DEEPTH - 1 : 0];
    
//���ʵ�ַ�ֽ�
    wire [OFFSET_WIDTH-1:0] offset;
    wire [INDEX_WIDTH-1:0] index;
    wire [TAG_WIDTH-1:0] tag;

    assign offset = cpu_data_addr[OFFSET_WIDTH - 1 : 0];
    assign index = cpu_data_addr[INDEX_WIDTH + OFFSET_WIDTH - 1 : OFFSET_WIDTH];
    assign tag = cpu_data_addr[31 : INDEX_WIDTH + OFFSET_WIDTH];
    
//����Cache line
    wire c_currused;
    wire c_valid;
    wire c_dirty;
    wire c_lastused;
    wire [TAG_WIDTH-1:0] c_tag;
    wire [31:0] c_block;
    assign c_currused = (cache_valid[1][index] & (cache_tag[1][index]==tag)) ? 1'b1 : 1'b0;
    assign c_valid = cache_valid[c_currused][index];
    assign c_tag   = cache_tag  [c_currused][index];
    assign c_block = cache_block[c_currused][index];        //����
    assign c_dirty = cache_dirty[c_currused][index];
    assign c_lastused = cache_lastused[index];
    
//�ж��Ƿ�����
    wire hit, miss;
    assign hit  = !no_cache & cpu_data_req & c_valid & (c_tag == tag);  //cache line��validλΪ1����tag���ַ��tag���
    assign miss = !no_cache & cpu_data_req & ~hit;

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
                IDLE:   state <= cpu_data_req & read & no_cache ? RM :
                                 cpu_data_req & write & no_cache ? WM :
                                 cpu_data_req & read & miss & !c_dirty & !except ? RM :         // ��ȱʧ�Ҹ�λû�б��޸�
                                 cpu_data_req & read & miss &  c_dirty & !except ? WM :         // ��ȱʧ�Ҹ�λ�޸Ĺ�
                                 cpu_data_req & read & hit  ? IDLE :                            // ������
                                 cpu_data_req & write & miss & c_dirty & !except & !write_miss_nodirty_save ? WM : IDLE;   // дȱʧ����dirty��д�ڴ�
                RM:     state <= read  & cache_data_data_ok ? IDLE : RM;
                WM:     state <= read & cache_data_data_ok & c_dirty ? RM :     // ��������д����Ϻ����
                                 write & cache_data_data_ok ? IDLE :            // д������д�����
                                 WM;    
            endcase
        end
    end

//���ڴ�
    //����read_req, addr_rcv, read_finish���ڹ�����sram�źš�
    wire read_req;      //һ�������Ķ����񣬴ӷ��������󵽽���;��ȡ�ڴ�����
    reg  addr_rcv;      //��ַ���ճɹ�(addr_ok)�󵽽���,�����ַ�Ѿ��յ���
    wire read_finish;   //���ݽ��ճɹ�(data_ok)�������������
    assign read_req = state==RM ;
    assign read_finish = read & cache_data_data_ok;
    always @(posedge clk) begin
        addr_rcv <= rst ? 1'b0 :
                    read & cache_data_req & cache_data_addr_ok ? 1'b1 :
                    read_finish ? 1'b0 : addr_rcv;
    end

//д�ڴ� 
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
    // �����漰״̬������Ҫһ��clk��������Ҫһ��reg���ӳ�һ��clk��������Ϊ�м�ʱ�ӷ���IDLE-->WM
    reg write_miss_nodirty_save; // дȱʧд�ɾ��ź���ӣ���Ϊ����״̬
    wire no_mem;                 // ����ô��ź�==>ֱ�����ֳɹ�   
    always @(posedge clk) begin
        if(rst) write_miss_nodirty_save <= 1'b0;
        else if (write & miss & !c_dirty & !no_cache) write_miss_nodirty_save <= 1'b1;
        else write_miss_nodirty_save <= 1'b0;
    end
    assign no_mem = (read & cpu_data_req & hit) |                // �����У�����ô�
                    (write & cpu_data_req & hit & !no_cache) |   // д���У�����ô�
                    write_miss_nodirty_save;                     // дȱʧд�ɾ�������ô�
    assign cpu_data_rdata   = hit ? c_block : cache_data_rdata;  //cache ���ظ�mips������
    assign cpu_data_addr_ok = no_mem | (cache_data_req & cache_data_addr_ok);
    assign cpu_data_data_ok = no_mem | (cache_data_data_ok);
                               

//output to axi interface
    // ��ȱʧ����λ
    assign cache_data_req   = read_req & ~addr_rcv | write_req & ~waddr_rcv;
    assign cache_data_wr    = ((state==IDLE) & miss & c_dirty) ? 1'b1 : cpu_data_wr;
    assign cache_data_size  = ((state==IDLE) & miss & c_dirty) ? 2'b10: cpu_data_size;
    assign cache_data_addr  = ((state==IDLE) & miss & c_dirty) ? {c_tag,index,2'b00} : cpu_data_addr;
    assign cache_data_wdata = ((state==IDLE) & miss & c_dirty) ? c_block : cpu_data_wdata;
    // ��һ��д����������Ҫreg״̬
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

//д��Cache
    //�����ַ�е�tag, index����ֹaddr�����ı�
    reg [TAG_WIDTH-1:0] tag_save;
    reg [INDEX_WIDTH-1:0] index_save;
    reg c_lastused_save;
    reg c_currused_save;
    always @(posedge clk) begin
        tag_save        <= rst ? 0 :
                         cpu_data_req ? tag : tag_save;
        index_save      <= rst ? 0 :
                         cpu_data_req ? index : index_save;
        c_lastused_save <= rst ? 0 :
                         cpu_data_req ? c_lastused : c_lastused_save;
        c_currused_save <= rst ? 0 :
                         cpu_data_req ? c_currused : c_currused_save;
    end

    // ͨ������ȷ��д�������
    wire [31:0] write_cache_data;
    wire [3:0] write_mask4;
    wire [31:0] write_mask32;
    //���ݵ�ַ����λ��size������д���루���sb��sh�Ȳ���д����һ���ֵ�ָ���4λ��Ӧ1���֣�4�ֽڣ���ÿ���ֵ�дʹ��
    assign write_mask4 = cpu_data_size==2'b00 ?
                            (cpu_data_addr[1] ? (cpu_data_addr[0] ? 4'b1000 : 4'b0100):
                                                (cpu_data_addr[0] ? 4'b0010 : 4'b0001)) :
                            (cpu_data_size==2'b01 ? (cpu_data_addr[1] ? 4'b1100 : 4'b0011) : 4'b1111);
    //�����ʹ�ã�λΪ1�Ĵ�����Ҫ���µġ�
    //λ��չ��{8{1'b1}} -> 8'b11111111
    //new_data = old_data & ~mask | write_data & mask
    assign write_mask32 = { {8{write_mask4[3]}}, {8{write_mask4[2]}}, {8{write_mask4[1]}}, {8{write_mask4[0]}} };
    assign write_cache_data = cache_block[c_currused][index] & ~write_mask32 | cpu_data_wdata & write_mask32; // Ĭ��ԭ���ݣ���д������д�����������

    // дcache
    integer t;
    always @(posedge clk) begin
        if(rst) begin
            for(t=0; t<CACHE_DEEPTH; t=t+1) begin   //�տ�ʼ��Cache��Ϊ��Ч
                cache_valid[0][t] <= 0;
                cache_valid[1][t] <= 0;
                cache_dirty[0][t] <= 0; 
                cache_dirty[1][t] <= 0; 
                cache_lastused[t] <= 0;
            end
        end
        else begin
            // ȱʧ�漰���滻way
            if(read_finish & !no_cache) begin  // ��ȱʧ���������
                // $display("��ȱʧ�������"); BUG �ô������ֱ��д��ò����Ҫsave����Ϣ
                cache_valid[!c_lastused_save][index_save] <= 1'b1;             //��Cache line��Ϊ��Ч
                cache_tag  [!c_lastused_save][index_save] <= tag_save;
                cache_block[!c_lastused_save][index_save] <= cache_data_rdata; //д��Cache line
                cache_dirty[!c_lastused_save][index_save] <= 1'b0;
                cache_lastused[index_save] <= !c_lastused_save;
            end
            else if(write & cpu_data_req & hit & !no_cache) begin   // д����ʱ��ҪдCache
                // $display("д����"); ֱ��д
                cache_block[c_currused][index] <= write_cache_data;             // д��Cache line��ʹ��index������index_save
                cache_dirty[c_currused][index] <= 1'b1;                         // д����ʱ��Ҫ����λ��Ϊ1
                cache_lastused[index] <= c_currused;
            end
            else if(write & (state==WM) & cache_data_data_ok & !no_cache) begin   // дȱʧ����һ��д�棬��ַ���ֳɹ���cpu_data_req��������
                // $display("дȱʧд��"); BUG �ô������ֱ��д��ò����Ҫsave����Ϣ
                cache_block[c_currused_save][index_save] <= write_cache_data;     
                cache_dirty[c_currused_save][index_save] <= 1'b1;
                cache_lastused[index_save] <= c_currused_save;
            end 
            else if(write & (state==IDLE) & write_miss_nodirty_save) begin   // дȱʧ+�ɾ����ֱ��д����
                // $display("дȱʧд�ɾ�"); ֱ��д
                cache_valid[!c_lastused][index] <= 1'b1;             //��Cache line��Ϊ��Ч
                cache_tag  [!c_lastused][index] <= tag;
                cache_block[!c_lastused][index] <= cpu_data_wdata;
                cache_dirty[!c_lastused][index] <= 1'b1;
                cache_lastused[index] <= !c_lastused;
            end
        end
    end
endmodule