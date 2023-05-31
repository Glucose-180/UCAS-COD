`timescale 10ns / 1ns

/* Instruction fetch stage */
module stage_IF(
	input clk,
	input rst,
	
	/* Instruction request channel */
	output reg [31:0] PC,
	output Inst_Req_Valid,
	input Inst_Req_Ready,

	/* Instruction response channel */
	input [31:0] Instruction,
	input Inst_Valid,
	output Inst_Ready,

	/* To next stage */
	output reg [31:0] IR,
	output wire Done_O,

	/* For branch */
	input [31:0] next_PC,
	input wire Feedback_Branch,
	
	/* For main memory access */
	input wire Feedback_Mem_Acc
);

	localparam s_INIT = 4'b0001, s_IF = 4'b0010,
		s_IW = 4'b0100, s_DN = 4'b1000;
	
	reg [3:0] current_state, next_state;

	/* Branch flag reg */
	reg BFR;

	/* FSM 1 */
	always @ (posedge clk) begin
		if (rst)
			current_state <= s_INIT;
		else
			current_state <= next_state;
	end

	/* FSM 2 */
	always @ (*) begin
		case (current_state)
		s_INIT:
			next_state = s_IF;
		s_IF:
			if (Inst_Req_Ready)
				next_state = s_IW;
			else
				next_state = s_IF;
		s_IW:
			if (Inst_Valid) begin
				if (Feedback_Branch || BFR)
					/* Branch will happen */
					next_state = s_IF;
				else
					next_state = s_DN;
			end
			else
				next_state = s_IW;
		default:	/* s_DN */
			if (Feedback_Mem_Acc)
				/* Pending */
				next_state = s_DN;
			else
				next_state = s_IF;
		endcase
	end

	/* PC */
	always @ (posedge clk) begin
		if (rst)
			PC <= 32'd0;
		else if (current_state == s_IW
			&& (Feedback_Branch || BFR))
			PC <= next_PC;
		else if (current_state == s_DN) begin
			if (Feedback_Branch || BFR)
				PC <= next_PC;  /* Branch */
			else
				PC <= PC + 32'd4;
		end
	end

	/* BFR */
	always @ (posedge clk) begin
		if (rst)		
			BFR <= 0;
		else if (Feedback_Branch)
			BFR <= 1;
		else if ((current_state == s_IW && Inst_Valid
			|| current_state == s_DN) && BFR)
			/* Clear branch flag when PC is renewed */
			BFR <= 0;
	end

	/* IR */
	always @ (posedge clk) begin
		if (current_state == s_IW && Inst_Valid)
			IR <= Instruction;
	end

	assign Done_O = (current_state == s_DN);

	assign Inst_Req_Valid = (current_state == s_IF),
		Inst_Ready = (current_state == s_IW || current_state == s_INIT);
endmodule

/* Instruction decode stage */
module stage_ID(
	input clk_I,
	input rst,

	/* Connect to last stage */
	input [31:0] IR,
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
	output reg [31:0] RR1,
	output reg [31:0] RR2,
	/* Regfile write address */
	output reg [4:0] RAR,
	/* Decode result: MAtype, x-Type, ALUop, SFTop */
	output reg [18:0] DCR,
	/* Decode result: Immediate */
	output reg [31:0] Imm_R,
	output reg Done_O,

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

	assign next_PC_temp = PC_I + Imm;

	/* next_PC */
	always @ (posedge clk) begin
		if (Done_I && !Feedback_Branch) begin
			if (Utype || Btype || Jtype || Itype_J)
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

	assign RF_raddr1 = IR[19:15],
		RF_raddr2 = IR[24:20],
		/* Only this 4 types have wirting request */
		RF_waddr = {5{Rtype || Itype || Utype || Jtype}} & IR[11:7];

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