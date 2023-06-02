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
* inst_retire (70-bit): detailed information of the retired instruction,
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

	/* Connect to regfile */
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
	wire [4:0] RF_waddr_23, RF_waddr_34;

	/* Decode result */
	wire [19:0] Decode_res;
	wire [31:0] Imm;
	wire [2:0] Funct3;

	/* Deal with RAW */
	wire [31:0] ASR_of_EX, MDR_of_MA;

	/* Memory */
	wire [5:0] Mem_Ctrl;
	wire [31:0] Mem_Write_data, Mem_Addr;

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

		.Feedback_Branch(Feedback_Branch),
		.Feedback_Mem_Acc(Feedback_Mem_Acc),

		.ASR_of_EX(ASR_of_EX), .MDR_of_MA(MDR_of_MA)
	);

	stage_EX EX_3(
		.clk_I(clk), .rst(rst),

		.Decode_res(Decode_res),
		.RF_rdata1(RF_rdata1_23), .RF_rdata2(RF_rdata2_23),
		.Done_I(Done_23), .PC_I(PC_23),
		.RF_waddr(RF_waddr_23), .Imm(Imm),

		.PC_O(PC_34), .Done_O(Done_34), .MCR(Mem_Ctrl),
		.WDR(Mem_Write_data), .ASR(Mem_Addr),
		.RAR(RF_waddr_34), .F3R(Funct3),

		.Feedback_Branch(Feedback_Branch),
		.Feedback_Mem_Acc(Feedback_Mem_Acc)
	);

	assign ASR_of_EX = Mem_Addr;

	stage_MA MA_4(
		.clk(clk), .rst(rst),

		.PC_I(PC_34), .Done_I(Done_34), .Mem_Ctrl(Mem_Ctrl),
		.Mem_wdata(Mem_Write_data), .Mem_Addr_I(Mem_Addr),
		.RF_waddr(RF_waddr_34), .Funct3(Funct3),

		.Mem_Addr_O(Address), .MemWrite(MemWrite),
		.Write_data(Write_data), .Write_strb(Write_strb),
		.MemRead(MemRead), .Mem_Req_Ready(Mem_Req_Ready),

		.Read_data(Read_data), .Read_data_Valid(Read_data_Valid),
		.Read_data_Ready(Read_data_Ready),

		.PC_O(PC_45), .Done_O(Done_45),
		.RF_wdata(RF_wdata), .RAR(RF_waddr),

		.Feedback_Mem_Acc(Feedback_Mem_Acc)
	);

	assign MDR_of_MA = RF_wdata;

	/* NOTE: RF_waddr and RF_wdata of Regfile are
	connected to stage_MA, while RF_wen is
	connected to stage_WB. */

	stage_WB WB_5(
		.clk(clk), .rst(rst),

		.PC_I(PC_45), .Done_I(Done_45),
		.RF_waddr(RF_waddr), .RF_wdata(RF_wdata),

		.RF_wen(RF_wen),

		.IRR(inst_retire)
	);

	
	localparam CM = 32'd999999999,	/* carryout max */
		UINT32_MAX = 32'hffffffff;	/* max of 32-bit unsigned int */

	/* Performance counter 0: cycle count(Low 9 digits) */
	reg [31:0] cycle_count_l;
	always @ (posedge clk)
		if (rst || cycle_count_l == CM)
			cycle_count_l <= 32'd0;
		else
			cycle_count_l <= cycle_count_l + 32'd1;
	assign cpu_perf_cnt_0 = cycle_count_l;

	/* Performance counter 1: cycle count(High G) */
	reg [31:0] cycle_count_h;
	always @ (posedge clk)
		if (rst)
			cycle_count_h <= 32'd0;
		else if (cycle_count_l == CM)
			cycle_count_h <= cycle_count_h + 32'd1;
	assign cpu_perf_cnt_1 = cycle_count_h;
	reg cycle_count_OF;	/* Overflow flag */
	always @ (posedge clk)
		if (rst)
			cycle_count_OF <= 1'b0;
		else if (cycle_count_h == UINT32_MAX)
			cycle_count_OF <= 1'b1;	/* Overflow! */

	/* Performance counter 2: instruction count(Low 9 digits) */
	reg [31:0] inst_count_l;
	always @ (posedge clk)
		if (rst || inst_count_l == CM)
			inst_count_l <= 32'd0;
		else if (Done_45)	/* use Done_O of stage_MA as a flag */
			inst_count_l <= inst_count_l + 32'd1;
	assign cpu_perf_cnt_2 = inst_count_l;

	/* Performance counter 3: instruction count(Hign G)  */
	reg [31:0] inst_count_h;
	always @ (posedge clk)
		if (rst)
			inst_count_h <= 32'd0;
		else if (inst_count_l == CM)
			inst_count_h <= inst_count_h + 32'd1;
	assign cpu_perf_cnt_3 = inst_count_h;
	reg inst_count_OF;	/* Overflow flag */
	always @ (posedge clk)
		if (rst)
			inst_count_OF <= 1'b0;
		else if (inst_count_h == UINT32_MAX)
			inst_count_OF <= 1'b1;	/* Overflow! */
	
	/* Performance counter 4: memory access instruction count */
	reg [31:0] mainst_count;
	always @ (posedge clk)
		if (rst)
			mainst_count <= 32'd0;
		else if (!Feedback_Mem_Acc && Done_23 &&
			(Decode_res[13] || Decode_res[11]))
			mainst_count <= mainst_count + 32'd1;
	assign cpu_perf_cnt_4 = mainst_count;

	/* Performance counter 5: load instruction count */
	reg [31:0] ldinst_count;
	always @ (posedge clk)
		if (rst)
			ldinst_count <= 32'd0;
		else if (!Feedback_Mem_Acc && Done_23 &&
			Decode_res[13])
			ldinst_count <= ldinst_count + 32'd1;
	assign cpu_perf_cnt_5 = ldinst_count;

	/* Performance counter 6: store instruction count */
	reg [31:0] stinst_count;
	always @ (posedge clk)
		if (rst)
			stinst_count <= 32'd0;
		else if (!Feedback_Mem_Acc && Done_23 &&
			Decode_res[11])
			stinst_count <= stinst_count + 32'd1;
	assign cpu_perf_cnt_6 = stinst_count;

	/* Performance counter 7: total load cycle count */
	reg [31:0] ld_cycle_count;
	always @ (posedge clk)
		if (rst)
			ld_cycle_count <= 32'd0;
		else if (MemRead || Read_data_Ready)
			ld_cycle_count <= ld_cycle_count + 32'd1;
		/* May be 1 greater than true value as
		Read_data_Ready is HIGH at the beginning */
	assign cpu_perf_cnt_7 = ld_cycle_count;

	/* Performance counter 8: total store cycle count */
	reg [31:0] st_cycle_count;
	always @ (posedge clk)
		if (rst)
			st_cycle_count <= 32'd0;
		else if (MemWrite)
			st_cycle_count <= st_cycle_count + 32'd1;
	assign cpu_perf_cnt_8 = st_cycle_count;
	
	/* Performance counter 9: overflow flags */
	assign cpu_perf_cnt_9 = { 30'd0,inst_count_OF,cycle_count_OF };
	/*	0: Neither
		1: cycle_count is overflow
		2: inst_count is overflow
		3: both	*/

endmodule
