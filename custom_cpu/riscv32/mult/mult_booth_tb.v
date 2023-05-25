`timescale 10 ns / 1 ns

`define RND32 {$random} % (33'd1 << 32)
`define DATA_WIDTH 31

module multiplier_test_g();
	reg [`DATA_WIDTH:0] A;
	reg [`DATA_WIDTH:0] B;
	wire [2 * `DATA_WIDTH + 1:0] P;
	reg clk;
	reg rst;
	wire done;

	integer i, j;

	multiplier multiplier_test_inst(A, B, P, clk, rst, done);

	initial begin
		for (i = 0; i < 20; i = i + 1) begin
			clk = 0;
			rst = 1;
			A = `RND32;
			B = `RND32;
			#10 clk = 1;
			#10 rst = 0;
			for (j = 0; j < 64; j = j + 1) begin
				clk = 0;
				#10 clk = 1;
				#10;
			end
		end
	end

	initial begin
		$dumpfile("multiplier.vcd");
		$dumpvars(0, multiplier_test_g);
	end
endmodule
