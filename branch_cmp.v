// branch比较模块(Decode阶段)
`include "defines.vh"
module branch_cmp (
    input wire[31:0]a,b,
    input wire [5:0]op, // instrD_op
    input wire [4:0]rt,
    output wire isB
);
    
    always @(*) begin
        case (op)
        //    `OP_BEQ   : isB <= ;
        //    `OP_BNE   : isB <= (a != b);
        //    `OP_BGTZ  : isB <= (a[31]==1'b0) && (a!=`ZeroWord);
        //    `OP_BLEZ  : isB <= (a[31]==1'b1) || (a==`ZeroWord);
        //    `OP_SPEC_B:
        //        case (rt)
        //            `RT_BGEZ, `RT_BGEZAL : isB <= (a[31]==1'b0);
        //            `RT_BLTZ, `RT_BLTZAL : isB <= (a[31]==1'b1);
        //            default: isB <= 1'b0;
        //        endcase
        //    default: isB <= 1'b0;
        endcase
    end
endmodule