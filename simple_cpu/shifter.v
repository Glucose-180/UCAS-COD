`timescale 10 ns / 1 ns

`define DATA_WIDTH 32

module shifter (
	input  [`DATA_WIDTH - 1:0] A,
	input  [              4:0] B,
	input  [              1:0] Shiftop,
	output [`DATA_WIDTH - 1:0] Result
);
	// TODO: Please add your logic code here
	wire signed[`DATA_WIDTH - 1:0] A;
	/* Shifter opcode */
	parameter LL = 2'b00, RL = 2'b10, RA = 2'b11;

	assign Result = (
		$signed({32{Shiftop == LL}}) & (A << B) |
		$signed({32{Shiftop == RL}}) & (A >> B) |
		$signed({32{Shiftop == RA}}) & (A >>> B)
	);
	/* The three $signed cannot be omitted!!! */
endmodule
