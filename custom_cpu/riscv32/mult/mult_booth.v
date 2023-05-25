/* Data with, not including signal bit */
`define DATA_WIDTH 31

module multiplier(
	input [`DATA_WIDTH:0] A,
	input [`DATA_WIDTH:0] B,
	output [2 * `DATA_WIDTH + 1:0] P,
	input clk,
	input rst,
	output done
);

	localparam s_ADD = 3'b001,
		s_SFT = 3'b010,
		s_DNE = 3'b100;

	localparam DW = 5'd31,   /* `DATA_WIDTH */
		ZEROy = 5'd0,
		ZEROd = 33'd0;
	reg [4:0] ymr;
	/* counter */

	reg [`DATA_WIDTH + 1:0] ACC, AX, Q;
	/*  ACC:	accumulator;
		AX:	  multiplier A;
		Q:	  multiplier B and result. */

	reg [2:0] current_state, next_state;

	/* FSM: current state */
	always @ (posedge clk) begin
		if (rst)
			if (B[0] == 1'b0)
				current_state <= s_SFT;
			else
				current_state <= s_ADD;
		else
			current_state <= next_state;
	end

	/* FSM: next state */
	always @ (*) begin
		case (current_state)
		s_ADD:
			if (ymr == ZEROy)
				next_state = s_DNE;
			else
				next_state = s_SFT;
		s_SFT:
			if (ymr == ZEROy)
				next_state = s_DNE;
			else if (Q[2] == Q[1])
				next_state = s_SFT;
			else	/* do + or - */
				next_state = s_ADD;
		default:	/* s_DNE */
			next_state = s_DNE;
		endcase
	end

	/* FSM: output */
	/* ymr */
	always @ (posedge clk) begin
		if (rst)
			ymr <= DW;
		else if (current_state == s_SFT) // && ymr == ZEROy
			ymr <= ymr - 1;
	end
	/* AX */
	always @ (posedge clk) begin
		if (rst)
			/* two signal bits */
			AX <= { A[`DATA_WIDTH],A };
	end
	/* ACC */
	always @ (posedge clk) begin
		if (rst)
			ACC <= ZEROd;
		else if (current_state == s_ADD)
			ACC <= ACC + (Q[1] ? ~AX : AX) + Q[1];
		else if (current_state == s_SFT && ymr != ZEROy)
			ACC <= { ACC[`DATA_WIDTH + 1],ACC[`DATA_WIDTH + 1:1] };
	end
	/* Q */
	always @ (posedge clk) begin
		if (rst)
			Q <= { B,1'd0 };
		else if (current_state == s_SFT && ymr != ZEROy)
			Q <= { ACC[0],Q[`DATA_WIDTH + 1:1] };
	end
	/* other */
	assign done = !rst && (current_state == s_DNE);
	assign P = { ACC,Q[`DATA_WIDTH + 1:2] };

endmodule
