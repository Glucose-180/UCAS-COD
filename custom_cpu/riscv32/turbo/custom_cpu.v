`timescale 10ns / 1ns

module custom_cpu(
	input         clk,
	input         rst,

	//Instruction request channel
	output reg [31:0] PC,
	output        Inst_Req_Valid,
	input         Inst_Req_Ready,

	//Instruction response channel
	input  [31:0] Instruction,
	input         Inst_Valid,
	output        Inst_Ready,

	//Memory request channel
	output [31:0] Address,
	output        MemWrite,
	output [31:0] Write_data,
	output [ 3:0] Write_strb,
	output        MemRead,
	input         Mem_Req_Ready,

	//Memory data response channel
	input  [31:0] Read_data,
	input         Read_data_Valid,
	output        Read_data_Ready,

	input         intr,

	output [31:0] cpu_perf_cnt_0,
	output [31:0] cpu_perf_cnt_1,
	output [31:0] cpu_perf_cnt_2,
	output [31:0] cpu_perf_cnt_3,
	output [31:0] cpu_perf_cnt_4,
	output [31:0] cpu_perf_cnt_5,
	output [31:0] cpu_perf_cnt_6,
	output [31:0] cpu_perf_cnt_7,
	output [31:0] cpu_perf_cnt_8,
	output [31:0] cpu_perf_cnt_9,
	output [31:0] cpu_perf_cnt_10,
	output [31:0] cpu_perf_cnt_11,
	output [31:0] cpu_perf_cnt_12,
	output [31:0] cpu_perf_cnt_13,
	output [31:0] cpu_perf_cnt_14,
	output [31:0] cpu_perf_cnt_15,

	output wire [69:0] inst_retire
);

/* The following signal is leveraged for behavioral simulation, 
* which is delivered to testbench.
*
* STUDENTS MUST CONTROL LOGICAL BEHAVIORS of THIS SIGNAL.
*
* inst_retired (70-bit): detailed information of the retired instruction,
* mainly including (in order) 
* { 
*   reg_file write-back enable  (69:69,  1-bit),
*   reg_file write-back address (68:64,  5-bit), 
*   reg_file write-back data    (63:32, 32-bit),  
*   retired PC                  (31: 0, 32-bit)
* }
*
*/

// TODO: Please add your custom CPU code here

	/* For reg file */
	wire RF_wen;
	wire [31:0] RF_rdata1, RF_rdata2, RF_wdata;
	wire [4:0] RF_raddr1, RF_raddr2, RF_waddr;

	/* PC */
	wire [31:0] PC_12, PC_23, PC_34, PC_45;

	/* Inst */
	wire [31:0] Inst_12;

	/* Done */
	wire Done_12, Done_23, Done_34, Done_45;

	/* Feedback */
	wire [31:0] next_PC;
	wire Feedback_Branch, Feedback_Mem_Acc;

	/* Regfile */
	wire [31:0] RF_rdata1_23, RF_rdata2_23;
	wire [4:0] RF_waddr_23;

	/* Decode result */
	wire [19:0] Decode_res;
	wire [31:0] Imm;

	/* Deal with RAW */
	wire [31:0] ASR_of_EX, MDR_of_MA;

	stage_IF IF_1(
		.clk(clk), .rst(rst),

		.PC(PC_12), .Inst_Req_Valid(Inst_Req_Valid),
		.Inst_Req_Ready(Inst_Req_Ready),

		.Instruction(Instruction),
		.Inst_Valid(Inst_Valid), .Inst_Ready(Inst_Ready),

		.IR(Inst_12), .Done_O(Done_12),

		.next_PC(next_PC), .Feedback_Branch(Feedback_Branch),
		.Feedback_Mem_Acc(Feedback_Mem_Acc)
	);

	stage_ID ID_2(
		.clk_I(clk), .rst(rst),

		.Inst(Inst_12), .Done_I(Done_12),
		.PC_I(PC_12), .next_PC(next_PC),

		.RF_rdata1(RF_rdata1), .RF_rdata2(RF_rdata2),
		.RF_raddr1(RF_raddr1), .RF_raddr2(RF_raddr2),

		.PC_O(PC_23), .Done_O(Done_23),
		.RR1(RF_rdata1_23), .RR2(RF_rdata2_23), .RAR(RF_waddr_23),
		.DCR(Decode_res), .Imm_R(Imm),

		.Feedback_Branch(Feedback_Branch), .Feedback_Mem_Acc(Feedback_Mem_Acc),

		.ASR_of_EX(ASR_of_EX), .MDR_of_MA(MDR_of_MA)
	);

	
endmodule
