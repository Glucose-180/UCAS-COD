`timescale 10 ns / 1 ns

`define DATA_WIDTH 32
`define RND32 {$random} % (33'd1 << 32)
module alu_test_g();
	reg  [`DATA_WIDTH - 1:0]  A;
	reg  [`DATA_WIDTH - 1:0]  B;
	reg  [              2:0]  ALUop;
	wire                      Overflow;
	wire                      CarryOut;
	wire                      Zero;
	wire [`DATA_WIDTH - 1:0]  Result;
	parameter AND = 3'b000, OR = 3'b001, ADD = 3'b010, SUB = 3'b110, SLT = 3'b111, XOR = 3'b100, NOR = 3'b101, SLTU = 3'b011;
	integer i;

	alu alu_tm(A, B, ALUop, Overflow, CarryOut, Zero, Result);

	initial begin
		ALUop = AND;
		for (i = 0; i < 10; i = i + 1) begin
			A = `RND32;
			B = `RND32;
			#10;
		end

		ALUop = OR;
		for (i = 0; i < 10; i = i + 1) begin
			A = `RND32;
			B = `RND32;
			#10;
		end

		ALUop = ADD;
		for (i = 0; i < 10; i = i + 1) begin
			A = `RND32;
			B = `RND32;
			#10;
		end

		ALUop = SUB;
		for (i = 0; i < 10; i = i + 1) begin
			A = `RND32;
			B = `RND32;
			#10;
		end

		ALUop = SLT;
		for (i = 0; i < 10; i = i + 1) begin
			A = `RND32;
			B = `RND32;
			#10;
		end

		ALUop = XOR;
		for (i = 0; i < 10; i = i + 1) begin
			A = `RND32;
			B = `RND32;
			#10;
		end

		ALUop = NOR;
		for (i = 0; i < 10; i = i + 1) begin
			A = `RND32;
			B = `RND32;
			#10;
		end

		ALUop = SLTU;
		for (i = 0; i < 10; i = i + 1) begin
			A = `RND32;
			B = `RND32;
			#10;
		end
		$finish;
	end

	/*initial
		#600 $finish;*/
	initial begin
		$dumpfile("alu.vcd");
		$dumpvars(0, alu_test_g);
	end
endmodule
