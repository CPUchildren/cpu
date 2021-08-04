`include "defines.vh"
module lsmem (
    input wire[5:0]opM,
    input wire[31:0]sel_rd2M, // writedata_4B
    input wire[31:0]alu_resM,
    input wire[31:0]data_sram_rdataM,
    input wire [31:0] pcM,

    output reg [3:0]data_sram_wenM,
    output reg [31:0]data_sram_wdataM,
    output reg [31:0]read_dataM,
    output reg adesM, adelM,
    output reg [31:0] bad_addr
);
    
// TODO 看看能不能转换为assign语句
always @(*) begin
    bad_addr <= pcM;
    adesM <= 1'b0;
    adelM <= 1'b0;
    case(opM)
         `OP_LW: begin
             data_sram_wenM <= 4'b0000;
             if(alu_resM[1:0] != 2'b00)begin
                 adelM <= 1'b1;
                 bad_addr <= alu_resM;
             end
             else begin
                 read_dataM <= data_sram_rdataM;
             end
         end
         `OP_LB: begin
             data_sram_wenM <= 4'b0000;
             case(alu_resM[1:0])
                 2'b11: read_dataM <= {{24{data_sram_rdataM[31]}},data_sram_rdataM[31:24]};
                 2'b10: read_dataM <= {{24{data_sram_rdataM[23]}},data_sram_rdataM[23:16]};
                 2'b01: read_dataM <= {{24{data_sram_rdataM[15]}},data_sram_rdataM[15:8]};
                 2'b00: read_dataM <= {{24{data_sram_rdataM[7]}},data_sram_rdataM[7:0]};
             endcase
         end
         `OP_LBU: begin
             data_sram_wenM <= 4'b0000;
             case(alu_resM[1:0])
                 2'b11: read_dataM <= {{24{1'b0}},data_sram_rdataM[31:24]};
                 2'b10: read_dataM <= {{24{1'b0}},data_sram_rdataM[23:16]};
                 2'b01: read_dataM <= {{24{1'b0}},data_sram_rdataM[15:8]};
                 2'b00: read_dataM <= {{24{1'b0}},data_sram_rdataM[7:0]};
             endcase
         end
         `OP_LH: begin
             data_sram_wenM <= 4'b0000;
             if(alu_resM[0] != 1'b0)begin
                 adelM <= 1'b1;
                 bad_addr <= alu_resM;
             end
             else begin
                 case(alu_resM[1])
                     2'b1: read_dataM <= {{24{data_sram_rdataM[31]}},data_sram_rdataM[31:16]};
                     2'b0: read_dataM <= {{24{data_sram_rdataM[15]}},data_sram_rdataM[15:0]};
                 endcase
             end
         end
         `OP_LHU: begin
             data_sram_wenM <= 4'b0000;
             if(alu_resM[0] != 1'b0)begin
                 adelM <= 1'b1;
                 bad_addr <= alu_resM;
             end
             else begin
                 case(alu_resM[1])
                     2'b1: read_dataM <= {{24{1'b0}},data_sram_rdataM[31:16]};
                     2'b0: read_dataM <= {{24{1'b0}},data_sram_rdataM[15:0]};
                 endcase
             end
         end
         `OP_SW: begin
             if(alu_resM[1:0] != 2'b00) begin
                 adesM <= 1'b1;
                 bad_addr <= alu_resM;
                 data_sram_wenM <= 4'b0000;
             end
             else begin 
                 data_sram_wdataM <= sel_rd2M;
                 data_sram_wenM <=4'b1111;
             end
         end
         `OP_SH: begin
             if(alu_resM[0] != 1'b0) begin
                 adesM <= 1'b1;
                 bad_addr <= alu_resM;
                 data_sram_wenM <= 4'b0000;
             end
             else begin
                 data_sram_wdataM <= {sel_rd2M[15:0],sel_rd2M[15:0]};
                 case(alu_resM[1:0])
                     2'b10: data_sram_wenM <= 4'b1100;
                     2'b00: data_sram_wenM <= 4'b0011;
                     default: ;
                 endcase
             end
         end
         `OP_SB: begin
             data_sram_wdataM <= {sel_rd2M[7:0],sel_rd2M[7:0],sel_rd2M[7:0],sel_rd2M[7:0]};
             case(alu_resM[1:0])
                 2'b11: data_sram_wenM <= 4'b1000;
                 2'b10: data_sram_wenM <= 4'b0100;
                 2'b01: data_sram_wenM <= 4'b0010;
                 2'b00: data_sram_wenM <= 4'b0001;
                 default: ;
             endcase
         end
        default : data_sram_wenM <= 4'b0000;
    endcase
end

endmodule

