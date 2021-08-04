// 仅用于instdec标注
// global macro definition
`define RstEnable 		1'b1
`define RstDisable		1'b0
`define ZeroWord		32'h00000000
`define WriteEnable		1'b1
`define WriteDisable	1'b0
`define ReadEnable		1'b1
`define ReadDisable		1'b0
`define AluOpBus		7:0
`define AluSelBus		2:0
`define InstValid		1'b0
`define InstInvalid		1'b1
`define Stop 			1'b1
`define NoStop 			1'b0
`define InDelaySlot 	1'b1
`define NotInDelaySlot 	1'b0
`define Branch 			1'b1
`define NotBranch 		1'b0
`define InterruptAssert 1'b1
`define InterruptNotAssert 1'b0
`define TrapAssert 		1'b1
`define TrapNotAssert 	1'b0
`define True_v			1'b1
`define False_v			1'b0
`define ChipEnable		1'b1
`define ChipDisable		1'b0
`define AHB_IDLE 2'b00
`define AHB_BUSY 2'b01
`define AHB_WAIT_FOR_STALL 2'b11

//specific inst macro definition



`define R_TYPE 6'b000000
`define REGIMM_INST 6'b000001
`define SPECIAL3_INST 6'b010000
//change the SPECIAL2_INST from 6'b011100 to 6'b010000
`define MTC0 5'b00100
`define MFC0 5'b00000

// ALU OP 4bit

`define ANDI_OP 4'b0000
`define XORI_OP 4'b0001
`define ORI_OP  4'b0010
`define LUI_OP  4'b0011
`define ADDI_OP 4'b0100
`define ADDIU_OP    4'b0101
`define SLTI_OP     4'b0110
`define SLTIU_OP    4'b0111

`define MEM_OP  4'b0100
`define R_TYPE_OP 4'b1000
`define MFC0_OP 4'b1001
`define MTC0_OP 4'b1010
`define USELESS_OP 4'b1111

// ALU CONTROL 5bit
`define AND_CONTROL 5'b00111
`define OR_CONTROL  5'b00001
`define XOR_CONTROL 5'b00010
`define NOR_CONTROL 5'b00011
`define LUI_CONTROL 5'b00100

`define SLL_CONTROL 5'b01000
`define SRL_CONTROL 5'b01001
`define SRA_CONTROL 5'b01010
`define SLLV_CONTROL    5'b01011
`define SRLV_CONTROL    5'b01100
`define SRAV_CONTROL    5'b01101

`define ADD_CONTROL     5'b10000
`define ADDU_CONTROL    5'b10001
`define SUB_CONTROL     5'b10010
`define SUBU_CONTROL    5'b10011
`define SLT_CONTROL     5'b10100
`define SLTU_CONTROL    5'b10101

`define MULT_CONTROL    5'b11000
`define MULTU_CONTROL   5'b11001
`define DIV_CONTROL     5'b11010
`define DIVU_CONTROL    5'b11011

`define MFHI_CONTROL  	5'b11100
`define MTHI_CONTROL  	5'b11101
`define MFLO_CONTROL  	5'b11110
`define MTLO_CONTROL  	5'b11111

`define MFC0_CONTROL 	5'b00101
`define MTC0_CONTROL 	5'b00110

//inst ROM macro definition
`define InstAddrBus		31:0
`define InstBus 		31:0

//data RAM
`define DataAddrBus 31:0
`define DataBus 31:0
`define ByteWidth 7:0

//regfiles macro definition

`define RegAddrBus		4:0
`define RegBus 			31:0
`define RegWidth		32
`define DoubleRegWidth	64
`define DoubleRegBus	63:0
`define RegNum			32
`define RegNumLog2		5
`define NOPRegAddr		5'b00000

//div
`define DivFree 2'b00
`define DivByZero 2'b01
`define DivOn 2'b10
`define DivEnd 2'b11
`define DivResultReady 1'b1
`define DivResultNotReady 1'b0
`define DivStart 1'b1
`define DivStop 1'b0

//CP0
`define CP0_REG_BADVADDR    5'b01000       
`define CP0_REG_COUNT    5'b01001        
`define CP0_REG_COMPARE    5'b01011      
`define CP0_REG_STATUS    5'b01100       
`define CP0_REG_CAUSE    5'b01101       
`define CP0_REG_EPC    5'b01110          
`define CP0_REG_PRID    5'b01111         
`define CP0_REG_CONFIG    5'b10000       