`timescale 10ns / 1ns

/* Instruction decode stage */
module stage_ID(
	input clk_I,
	input rst,

	/* Connect to last stage */
	input [31:0] Inst,
	input Done_I,
	input PC_I,
	output reg [31:0] next_PC,

	/* Connect to Regfile */
	input [31:0] RF_rdata1,
	input [31:0] RF_rdata2,
	output [4:0] RF_raddr1,
	output [4:0] RF_raddr2,
	
	/* Connect to next stage */
	output reg [31:0] PC_O,
	output reg Done_O,
	/* Regfile read data */
	output reg [31:0] RR1,
	output reg [31:0] RR2,
	/* Regfile write address */
	output reg [4:0] RAR,
	/* Decode result:
	[AUIPC], MAtype(Funct3), x-Type, ALUop, SFTop */
	output reg [19:0] DCR,
	/* Decode result: Immediate */
	output reg [31:0] Imm_R,

	/* Feedback */
	input wire Feedback_Branch,
	input wire Feedback_Mem_Acc,

	/* Deal with RAW */
	input [31:0] ASR_of_EX,
	input [31:0] MDR_of_MA
);

	wire clk;
	//reg LPR;	/* Load pending flag reg */

	/* Decode */
	wire Rtype, Itype_CS, Itype_L, Stype,
		Itype_J, Utype, Btype, Jtype, Itype, MUL;
	/* CS: Calc and shift; L: Load. */
	/* Note: [jalr] is considered as J-Type. */
	wire SFTtype;	/* shift instruction */
	wire [31:0] Imm;	/* Immediates */
	wire [6:0] Opcode, Funct7;
	wire [2:0] Funct3;

	wire [31:0] next_PC_temp;

	wire [2:0] ALUop;
	wire [1:0] SFTop;

	wire [4:0] RF_waddr;

	/* RAW data correlation */
	wire RAW1, RAW2;

	wire [2:0] MA_type;

	/* CONST */
	localparam s_INIT = 9'h1, s_IF = 9'h2, s_IW = 9'h4,
		s_ID = 9'h8, s_EX = 9'h10, s_LD = 9'h20, s_RDW = 9'h40,
		s_ST = 9'h80, s_WB = 9'h100;
	localparam OC_auipc = 7'b0010111,
		OC_jal = 7'b1101111, OC_jalr = 7'b1100111;
	localparam ALU_ADD = 3'b000, ALU_SLT = 3'b010,
		ALU_SLTU = 3'b011, ALU_SUB = 3'b001;

	/* Effective clock */
	assign clk = (clk_I & (rst | ~Feedback_Mem_Acc));

	/* ASSIGN */
	assign Rtype = (Opcode == 7'b0110011),
		Itype_CS = (Opcode == 7'b0010011),
		Itype_L = (Opcode == 7'b0000011),
		Itype_J = (Opcode == OC_jalr),
		Stype = (Opcode == 7'b0100011),
		Utype = ({ Opcode[6],Opcode[4:0] } == 6'b010111),
		Btype = (Opcode == 7'b1100011),
		Jtype = (Opcode == OC_jal);
	assign MUL = (Rtype && Funct3 == 3'd0 && Funct7 == 7'd1);
	/* [MUL] instruction */
	assign Itype = Itype_CS || Itype_J || Itype_L;
	assign SFTtype = (Itype_CS || Rtype) && (Funct3[1:0] == 2'b01);
	assign Imm = {
/* 31 */	Inst[31],
/* 30~20 */	(Utype ? Inst[30:20] : {11{Inst[31]}}),
/* 19~12 */	(Utype || Jtype ? Inst[19:12] : {8{Inst[31]}}),
/* 11 */	(Itype || Stype) & Inst[31] |
			Btype & Inst[7] |	Jtype & Inst[20],
/* 10~5 */	~{6{Utype}} & Inst[30:25],
/* 4~1 */	{4{Itype  || Jtype}} & Inst[24:21] |
			{4{Stype || Btype}} & Inst[11:8],
/* 0 */		Itype & Inst[20] | Stype & Inst[7]
	};
	assign Opcode = Inst[6:0];
	assign Funct3 = Inst[14:12], Funct7 = Inst[31:25];

	assign next_PC_temp = PC_I + Imm;

	/* next_PC */
	always @ (posedge clk) begin
		if (Done_I && !Feedback_Branch) begin
			if (/*Utype || */Btype || Jtype || Itype_J)
				next_PC <= { next_PC_temp[31:2],2'd0 };
		end
	end

	/* PC_O */
	always @ (posedge clk) begin
		if (Done_I && !Feedback_Branch)
			PC_O <= PC_I;
	end

	/* Done_O */
	always @ (posedge clk) begin
		if (rst)
			Done_O <= 0;
		else if (Done_I && !Feedback_Branch)
			Done_O <= 1;
		else
			Done_O <= 0;
	end

	assign ALUop = (
			{3{Rtype}} & (Funct3 | { 2'd0,Funct7[5] }) |
			{3{Itype_CS}} & Funct3 |
			/* Well designed! */
			{3{Itype_L || Stype || Utype || Jtype || Itype_J}} & ALU_ADD |
			{3{Btype}} & { 1'd0,Funct3[2],~(Funct3[2] ^ Funct3[1]) }
			/* SUB, SLT, SLTU */
		);
	assign SFTop = { Funct3[2],Funct7[5] };

	/* DCR */
	always @ (posedge clk) begin
		if (Done_I && !Feedback_Branch)
			DCR <= {
/* 19 */		(Opcode == OC_auipc),
/* 18~16 */		MA_type,	/* Funct3 */
/* 15~12 */		Rtype,Itype_CS,Itype_L,Itype_J,
/* 11~7 */		Stype,Utype,Btype,Jtype,MUL,
/* 6~0 */		Itype,SFTtype,ALUop,SFTop
			};
	end

	assign MA_type = Funct3;

	/* Imm_R */
	always @ (posedge clk) begin
		if (Done_I && !Feedback_Branch)
			Imm_R <= Imm;
	end

	assign RF_raddr1 = Inst[19:15],
		RF_raddr2 = Inst[24:20],
		/* Only this 4 types have wirting request */
		RF_waddr = {5{Rtype || Itype || Utype || Jtype}} & Inst[11:7];

	/* RAR */
	always @ (posedge clk) begin
		if (rst)
			RAR <= 5'd0;
		else if (Done_I && !Feedback_Branch)
			RAR <= RF_waddr;
	end

	assign RAW1 = (RAR != 5'd0 && RF_raddr1 == RAR),
		RAW2 = (RAR != 5'd0 && RF_raddr2 == RAR);
	
	/* RR1 and RR2 */
	always @ (posedge clk) begin
		if (RAW1) begin
			if (DCR[13])
				/* The last inst is LOAD */
				RR1 <= MDR_of_MA;
			else
				RR1 <= ASR_of_EX;
		end
		else
			RR1 <= RF_rdata1;
	end
	always @ (posedge clk) begin
		if (RAW2) begin
			if (DCR[13])
				/* The last inst is LOAD */
				RR2 <= MDR_of_MA;
			else
				RR2 <= ASR_of_EX;
		end
		else
			RR2 <= RF_rdata2;
	end
endmodule