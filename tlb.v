module tlb (
    input  wire[31:0] inst_sram_addr_temp,
    output wire no_inst_cache,
    output wire[31:0] inst_sram_addr,

    input  wire[31:0] data_sram_addr_temp,
    output wire no_data_cache,
    output wire[31:0] data_sram_addr
);
    assign data_sram_addr = (data_sram_addr_temp[31:16]==16'hbfaf || 
                             data_sram_addr_temp[31:16]==16'h1faf) ? 
                            {3'b0, data_sram_addr_temp[28:0]} : data_sram_addr_temp;
    assign no_data_cache = data_sram_addr_temp[31:16]==16'hbfaf || 
                           data_sram_addr_temp[31:16]==16'h1faf;
    
    assign inst_sram_addr = (inst_sram_addr_temp[31:16]==16'hbfaf || 
                             inst_sram_addr_temp[31:16]==16'h1faf) ? 
                            {3'b0, inst_sram_addr_temp[28:0]} : inst_sram_addr_temp;
    assign no_inst_cache = inst_sram_addr_temp[31:16]==16'hbfaf || 
                           inst_sram_addr_temp[31:16]==16'h1faf;
endmodule