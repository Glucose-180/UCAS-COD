`timescale 10 ns / 1 ns
`define DATA_WIDTH 32
`define RND32 {$random} % (33'd1 << 32)
`define RND5 {$random} % (6'd1 << 5)

module shifter_test_g();
	reg  [`DATA_WIDTH - 1:0] A;
	reg  [              4:0] B;
	reg  [              1:0] Shiftop;
	wire [`DATA_WIDTH - 1:0] Result;

	shifter shifter_test_inst(A, B, Shiftop, Result);
	/* Shifter opcode */
	parameter LL = 2'b00, RL = 2'b10, RA = 2'b11;

	integer i;
	initial begin
		Shiftop = LL; // Left
		for (i = 0; i < 10; i = i + 1) begin
			A = `RND32;
			B = `RND5;
			#10;
		end

		Shiftop = RL; // Right Logic
		for (i = 0; i < 10; i = i + 1) begin
			A = `RND32;
			B = `RND5;
			#10;
		end

		Shiftop = RA; // Right Arthi
		for (i = 0; i < 10; i = i + 1) begin
			A = `RND32;
			B = `RND5;
			#10;
		end
		//$finish;
	end
	initial begin
		$dumpfile("shifter.vcd");
		$dumpvars(0, shifter_test_g);
	end
endmodule
