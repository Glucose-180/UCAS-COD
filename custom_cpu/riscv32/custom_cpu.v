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
	reg [31:0] RR1, RR2;

	/* For instruction */
	reg [31:0] IR, PCs4;
	wire Rtype, Itype_CS, Itype_L, Stype, Utype, Btype, Jtype;
	/* CS: Calc and shift; L: Load. */
	/* Note: [jalr] is considered as J-Type. */
	wire SFTtype;	/* shift instruction */
	wire [31:0] Imm;
	/* Immediates */
	wire [6:0] Opcode, Funct7;
	wire [2:0] Funct3;

	/* For ALU and shifter */
	wire [31:0] ALU_A, ALU_B, ALU_res;
	wire [2:0] ALUop;
	wire ALU_ZF, ALU_CF, ALU_OF;
	wire [31:0] SFT_A, SFT_B, SFT_res;
	wire [1:0] SFTop;
	reg [31:0] ASR;	/* ALU & SFT reg */

	/* For FSM */
	reg [8:0] current_state, next_state;
	/* For RAM */
	reg [31:0] MDR;	/* Memory data reg */
	wire [7:0] LoadB;
	wire [15:0] LoadH;

	/* CONST */
	localparam s_INIT = 9'h1, s_IF = 9'h2, s_IW = 9'h4,
		s_ID = 9'h8, s_EX = 9'h10, s_LD = 9'h20, s_RDW = 9'h40,
		s_ST = 9'h80, s_WB = 9'h100;
	localparam OC_auipc = 7'b0010111,
		OC_jal = 7'b1101111, OC_jalr = 7'b1100111;
	localparam ALU_ADD = 3'b000, ALU_SLT = 3'b010,
		ALU_SLTU = 3'b011, ALU_SUB = 3'b001;

	/* ASSIGN */
	assign Rtype = (Opcode == 7'b0110011),
		Itype_CS = (Opcode == 7'b0010011),
		Itype_L = (Opcode == 7'b0000011),
		Itype_J = (Opcode == OC_jalr),
		Stype = (Opcode == 7'b0100011),
		Utype = ({ Opcode[6],Opcode[4:0] } == 6'b010111),
		Btype = (Opcode == 7'b1100011),
		Jtype = (Opcode == OC_jal);
	assign Itype = Itype_CS || Itype_J || Itype_L;
	assign SFTtype = (Itype_CS || Rtype) && (Funct3[1:0] == 2'b01);
	assign Imm = {
/* 31 */	IR[31],
/* 30~20 */	(Utype ? IR[30:20] : {11{IR[31]}}),
/* 19~12 */	(Utype || Jtype ? IR[19:12] : {8{IR[31]}}),
/* 11 */	(Itype || Stype) & IR[31] |
			Btype & IR[7] |	Jtype & IR[20],
/* 10~5 */	~{6{Utype}} & IR[30:25],
/* 4~1 */	{4{Itype  || Jtype}} & IR[24:21] |
			{4{Stype || Btype}} & IR[11:8],
/* 0 */		Itype & IR[20] | Stype & IR[7]
	};
	assign Opcode = IR[6:0];
	assign Funct3 = IR[14:12], Funct7 = IR[31:25];

	/* Instantiation of the register file module */
	reg_file RF (
		.clk(clk), .waddr(RF_waddr), .wen(RF_wen), .wdata(RF_wdata),
		.raddr1(RF_raddr1), .raddr2(RF_raddr2), .rdata1(RF_rdata1), .rdata2(RF_rdata2)
	);
	/* Instantiation of the ALU module */
	alu ALU (
		.A(ALU_A), .B(ALU_B), .ALUop(ALUop), .Overflow(ALU_OF),
		.CarryOut(ALU_CF), .Zero(ALU_ZF), .Result(ALU_res)
	);
	/* Instantiation of the shifter module */
	shifter SFT (
		.A(SFT_A), .B(SFT_B), .Shiftop(SFTop), .Result(SFT_res)
	);

	/* FSM: state switch */
	always @ (posedge clk)
		if (rst)
			current_state <= s_INIT;
		else
			current_state <= next_state;
	/* FSM: next state */
	always @ (*) begin
		case (current_state)
		s_INIT:	/* Initial */
			if (rst == 0)
				next_state = s_IF;
			else
				next_state = s_INIT;
		s_IF:	/* Instruction fetch */
			if (Inst_Req_Ready)
				next_state = s_IW;
			else
				next_state = s_IF;
		s_IW:	/* Instruction waiting */
			if (Inst_Valid)
				next_state = s_ID;
			else
				next_state = s_IW;
		s_ID:	/* Instruction decoding */
			next_state = s_EX;
		s_EX:	/* Executing */
			if (Btype)
				next_state = s_IF;
			else if (Rtype || Itype_CS || Utype || Jtype || Itype_J)
				next_state = s_WB;
			else if (Itype_L)
				next_state = s_LD;
			else	/* Stype */
				next_state = s_ST;
		s_ST:	/* Storing */
			if (Mem_Req_Ready)
				next_state = s_IF;
			else
				next_state = s_ST;
		s_LD:	/* Loading */
			if (Mem_Req_Ready)
				next_state = s_RDW;
			else
				next_state = s_LD;
		s_RDW:	/* Read data waiting */
			if (Read_data_Valid)
				next_state = s_WB;
			else
				next_state = s_RDW;
		s_WB:	/* Writing back */
			next_state = s_IF;
		default:
			next_state = s_INIT;
		endcase
	end
	/* FSM: output */
	/* PC */
	always @ (posedge clk) begin
		if (rst)
			PC <= 32'd0;
		else if (current_state == s_IF && Inst_Req_Ready)
			PC <= ALU_res;	/* PC <= PC + 4 */
		else if (current_state == s_EX) begin
			if (Opcode == OC_auipc)
				PC <= ALU_res;
			else if (Btype && (Funct3[2] ^ Funct3[0] ^ ALU_ZF)
				|| Jtype || Itype_J)
				PC <= { ASR[31:1],1'd0 };
		end
	end
	/* PCs4 */
	always @ (posedge clk) begin
		if (current_state == s_IF && Inst_Req_Ready)
			PCs4 <= PC;
			/* PCs4 points to current instruction,
			   while PC points to next instruction. */
	end
	/* IR */
	always @ (posedge clk) begin
		if (current_state == s_IW && Inst_Valid)
			IR <= Instruction;
	end
	/* RR */
	always @ (posedge clk) begin
		if (current_state == s_ID)
			RR1 <= RF_rdata1;
	end
	always @ (posedge clk) begin
		if (current_state == s_ID)
			RR2 <= RF_rdata2;
	end
	/* ASR */
	always @ (posedge clk) begin
		if (current_state == s_EX && SFTtype)
			ASR <= SFT_res;
		else if (current_state == s_EX && Utype)
			ASR <= Imm;	/* [LUI] */
		else if (current_state == s_EX ||
			current_state == s_ID && (Btype || Jtype || Itype_J))
			ASR <= ALU_res;
	end
	/* MDR */
	always @ (posedge clk) begin
		if (current_state == s_RDW && Read_data_Valid)
			MDR <= Read_data;
		else if (current_state == s_EX && Stype)
			MDR <= (
				{32{Funct3[1:0] == 2'b00}} & (RR2 << { ALU_res[1:0],3'd0 }) |
				/* [SB] */
				{32{Funct3[1:0] == 2'b01}} & (RR2 << { ALU_res[1],4'd0 }) |
				/* [SH] */
				{32{Funct3[1:0] == 2'b10}} & RR2
				/* [SW] */
			);
	end
	/* ALU */
	assign ALU_A = (
		{32{current_state == s_IF}} & PC |
		{32{current_state == s_ID}} &
			(Itype_J ? RF_rdata1 : PCs4) |
		{32{current_state == s_EX}} & (Jtype || Itype_J || Utype ? PCs4 : RR1)
	);
	assign ALU_B = (
		{32{current_state == s_IF}} & 32'd4 |
		{32{current_state == s_ID}} & Imm |
		{32{current_state == s_EX}} & (
			{32{Rtype || Btype}} & RR2 |
			{32{Itype_CS || Itype_L || Stype || Utype}} & Imm |
			{32{Jtype || Itype_J}} & 32'd4
		)
	);
	assign ALUop = (
		{3{current_state == s_IF || current_state == s_ID}} & ALU_ADD |
		{3{current_state == s_EX}} & (
			{3{Rtype}} & (Funct3 | { 2'd0,Funct7[5] }) |
			{3{Itype_CS}} & Funct3 |
			/* Well designed! */
			{3{Itype_L || Stype || Utype || Jtype || Itype_J}} & ALU_ADD |
			{3{Btype}} & { 1'd0,Funct3[2],~(Funct3[2] ^ Funct3[1]) }
			/* SUB, SLT, SLTU */
		)
	);
	/* SFT */
	assign SFT_A = {32{current_state == s_EX}} & RR1,
		SFT_B = {5{current_state == s_EX}} & (
		{5{Rtype}} & RR2[4:0] |
		{5{Itype_CS}} & Imm[4:0]
	);
	assign SFTop = { Funct3[2],Funct7[5] };
	/* RF */
	assign RF_raddr1 = IR[19:15],
		RF_raddr2 = IR[24:20],
		RF_waddr = IR[11:7];
	assign RF_wen = (
		current_state == s_WB && 
			(Rtype || Itype || Utype || Jtype)
	);
	assign RF_wdata = (
		{32{Rtype || Itype_CS || Utype || Jtype || Itype_J}} & ASR |
		{32{Itype_L}} & (
			{32{Funct3[1:0] == 2'b00}} &
				{ (Funct3[2] ? 24'd0 : {24{LoadB[7]}}),LoadB } |
			/* [LBU], [LB] */
			{32{Funct3[1:0] == 2'b01}} &
				{ (Funct3[2] ? 16'd0 : {24{LoadH[15]}}),LoadH } |
			/* [LHU], [LH] */
			{32{Funct3[1:0] == 2'b10}} & MDR
			/* [LW] */
		)
	);
	assign LoadB = MDR[{ ASR[1:0],3'd0 } +: 8],
		LoadH = MDR[{ ASR[1],4'd0 } +: 16];
	/* RAM */
	assign MemRead = (current_state == s_LD),
		MemWrite = (current_state == s_ST);
	assign Inst_Req_Valid = (current_state == s_IF),
		Inst_Ready = (current_state == s_IW || current_state == s_INIT),
		Read_data_Ready = (current_state == s_RDW || current_state == s_INIT);
	assign Address = { ASR[31:2],2'd0 };
	assign Write_data = MDR,
		Write_strb = (
			{4{Funct3[1:0] == 2'b00}} & (4'd1 << ASR[1:0]) |
			/* [SB] */
			{4{Funct3[1:0] == 2'b01}} & (4'd3 << { ASR[1],1'd0 }) |
			/* [SH] */
			{4{Funct3[1:0] == 2'b10}} & 4'd15
			/* [SW] */
		);
	
	/* Performance counter 0: cycle count */
	reg [31:0] cycle_count;
	always @ (posedge clk)
		if (rst)
			cycle_count <= 32'd0;
		else
			cycle_count <= cycle_count + 32'd1;
	assign cpu_perf_cnt_0 = cycle_count;

	/* Performance counter 1: instruction count */
	reg [31:0] inst_count;
	always @ (posedge clk)
		if (rst)
			inst_count <= 32'd0;
		else if (current_state == s_ID)
			inst_count <= inst_count + 32'd1;
	assign cpu_perf_cnt_1 = inst_count;

	/* Performance counter 2: memory access instruction count */
	reg [31:0] mainst_count;
	always @ (posedge clk)
		if (rst)
			mainst_count <= 32'd0;
		else if (current_state == s_ID && (Itype_L || Stype))
			mainst_count <= mainst_count + 32'd1;
	assign cpu_perf_cnt_2 = mainst_count;

	/* Performance counter 3: load instruction count */
	reg [31:0] ldinst_count;
	always @ (posedge clk)
		if (rst)
			ldinst_count <= 32'd0;
		else if (current_state == s_ID && Itype_L)
			ldinst_count <= ldinst_count + 32'd1;
	assign cpu_perf_cnt_3 = ldinst_count;

	/* Performance counter 4: store instruction count */
	reg [31:0] stinst_count;
	always @ (posedge clk)
		if (rst)
			stinst_count <= 32'd0;
		else if (current_state == s_ID && Utype)
			stinst_count <= stinst_count + 32'd1;
	assign cpu_perf_cnt_4 = stinst_count;

	/* Performance counter 5: total load cycle count */
	reg [31:0] ld_cycle_count;
	always @ (posedge clk)
		if (rst)
			ld_cycle_count <= 32'd0;
		else if (current_state == s_LD || current_state == s_RDW)
			ld_cycle_count <= ld_cycle_count + 32'd1;
	assign cpu_perf_cnt_5 = ld_cycle_count;

	/* Performance counter 6: total store cycle count */
	reg [31:0] st_cycle_count;
	always @ (posedge clk)
		if (rst)
			st_cycle_count <= 32'd0;
		else if (current_state == s_ST)
			st_cycle_count <= st_cycle_count + 32'd1;
	assign cpu_perf_cnt_6 = st_cycle_count;
endmodule
