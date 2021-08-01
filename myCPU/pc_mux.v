`timescale 1ns/1ps
module pc_mux(
    input  wire jumpD,
    input  wire jalD,
    input  wire jrD,
    input  wire pcsrcD,
    input  wire[31:0] excepttypeM,
    input  wire[31:0] pc_next_jump,
    input  wire[31:0] pc_next_jr,
    input  wire[31:0] pc_plus4F,
    input  wire[31:0] pc_branchD,
    input  wire[31:0] newpcM,

    output wire [31:0] pc_next
);
    assign pc_next = (|excepttypeM) ? newpcM :  // 注意优先级依次降低
                     jrD            ? pc_next_jr:
                     (jumpD|jalD)   ? pc_next_jump :
                     pcsrcD         ? pc_branchD : 
                                      pc_plus4F;
endmodule