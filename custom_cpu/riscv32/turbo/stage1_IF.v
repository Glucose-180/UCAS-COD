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
