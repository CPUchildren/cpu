module lsmem (
    input wire[5:0]opM,
    input wire[31:0]sel_rd2M,
    input wire[31:0]data_sram_rdataM,

    output wire[3:0]data_sram_wenM,
    output wire[31:0]data_sram_wdataM,
    output wire[31:0]read_dataM
);
    
always @(*) begin
    case(opM)
        `OP_LW,`OP_LB,`OP_LBU,`OP_LH,`OP_LHU: data_sram_wenM <= 4'b0000;
        `OP_SW: begin
            data_sram_wdataM <= sel_rd2M;
            data_sram_wenM <=4'b1111;
        end
        `OP_SH: begin
            data_sram_wdataM <= {sel_rd2M[15:0],sel_rd2M[15:0]};
            case(alu_resM[1:0])
                2'b00: data_sram_wenM <= 4'b1100;
                2'b10: data_sram_wenM <= 4'b0011;
                // TODO 异常处理
                default: ;
            endcase
        end
        `OP_SB: begin
            data_sram_wdataM <= {sel_rd2M[7:0],sel_rd2M[7:0],sel_rd2M[7:0],sel_rd2M[7:0]};
            case(alu_resM[1:0])
                // TODO 大端小端的问题
                2'b00: data_sram_wenM <= 4'b1000;
                2'b01: data_sram_wenM <= 4'b0100;
                2'b10: data_sram_wenM <= 4'b0010;
                2'b11: data_sram_wenM <= 4'b0001;
                default: ;
            endcase
        end
    endcase
end

always @(*) begin
    case(opM)
        `OP_LW: begin
            read_dataM <= data_sram_rdataM;
        end
        `OP_LB: begin
            case(alu_resM[1:0])
                2'b00: read_dataM <= {{24{data_sram_rdataM[31]}},data_sram_rdataM[31:24]};
                2'b01: read_dataM <= {{24{data_sram_rdataM[23]}},data_sram_rdataM[23:16]};
                2'b10: read_dataM <= {{24{data_sram_rdataM[15]}},data_sram_rdataM[15:8]};
                2'b11: read_dataM <= {{24{data_sram_rdataM[7]}},data_sram_rdataM[7:0]};
            endcase
        end
        `OP_LBU: begin
            case(alu_resM[1:0])
                2'b00: read_dataM <= {{24{0}},data_sram_rdataM[31:24]};
                2'b01: read_dataM <= {{24{0}},data_sram_rdataM[23:16]};
                2'b10: read_dataM <= {{24{0}},data_sram_rdataM[15:8]};
                2'b11: read_dataM <= {{24{0}},data_sram_rdataM[7:0]};
            endcase
        end
        `OP_LH: begin
            case(alu_resM[1])
                2'b0: read_dataM <= {{24{data_sram_rdataM[31]}},data_sram_rdataM[31:16]};
                2'b1: read_dataM <= {{24{data_sram_rdataM[15]}},data_sram_rdataM[15:0]};
            endcase
        end
        `OP_LHU: begin
            case(alu_resM[1])
                2'b0: read_dataM <= {{24{0}},data_sram_rdataM[31:16]};
                2'b1: read_dataM <= {{24{0}},data_sram_rdataM[15:0]};
            endcase
        end
        default: ;
    endcase
end
endmodule