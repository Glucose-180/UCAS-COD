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

	localparam s_IF = 4'b0001, s_IW = 4'b0010,
		s_DN = 4'b0100, s_TMP = 4'b1000;
	/* TMP is a temporary state used when
	a branch instruction is fetched */

	localparam OC_jal = 7'b1101111, OC_jalr = 7'b1100111;
	
	reg [3:0] current_state, next_state;

	/* Serve as a flag of virtual initial state */
	reg IFR;

	wire [6:0] Opcode;

	/* A branch instruction was fetched */
	wire Flag_Branch;

	assign Opcode = IR[6:0];
	assign Flag_Branch = (
		Opcode == OC_jal || Opcode == OC_jalr ||
		Opcode == 7'b1100011 /* Btype */
	);

	/* FSM 1 */
	always @ (posedge clk) begin
		if (rst)
			current_state <= s_IF;
		else
			current_state <= next_state;
	end

	/* FSM 2 */
	always @ (*) begin
		case (current_state)
		s_IF:
			if (!IFR && Inst_Req_Ready)
				/* IFR: Virtual init state */
				next_state = s_IW;
			else
				next_state = s_IF;
		s_IW:
			if (Inst_Valid)
				next_state = s_DN;
			else
				next_state = s_IW;
		s_DN:
			if (Feedback_Mem_Acc)
				/* Pending */
				next_state = s_DN;
			else if (Flag_Branch)
				next_state = s_TMP;
			else
				next_state = s_IF;
		default:	/* s_TMP */
			if (Feedback_Mem_Acc)
				next_state = s_TMP;
			else
				next_state = s_IF;
		endcase
	end

	/* PC */
	always @ (posedge clk) begin
		if (rst)
			PC <= 32'd0;
		else if (current_state == s_DN && next_state == s_IF ||
			current_state == s_TMP && !Feedback_Branch && next_state == s_IF)
				PC <= PC + 32'd4;
		else if (current_state == s_TMP && Feedback_Branch)
				PC <= next_PC;
	end

	/* IR */
	always @ (posedge clk) begin
		if (current_state == s_IW && Inst_Valid)
			IR <= Instruction;
	end

	/* IFR */
	always @ (posedge clk) begin
		IFR <= rst;
		/* To yield a virtual initial state */
	end

	assign Done_O = (current_state == s_DN);

	assign Inst_Req_Valid = (!rst && current_state == s_IF && !IFR),
		Inst_Ready = (rst || current_state == s_IW || IFR);
endmodule
