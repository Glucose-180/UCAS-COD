`timescale 10 ns / 1 ns

`define DATA_WIDTH 32

module alu(
	input  [`DATA_WIDTH - 1:0]  A,
	input  [`DATA_WIDTH - 1:0]  B,
	input  [              2:0]  ALUop,
	output                      Overflow,
	output                      CarryOut,
	output                      Zero,
	output [`DATA_WIDTH - 1:0]  Result
);
	// TODO: Please add your logic design here
	/* ALU opcode */
	parameter AND = 3'b000, OR = 3'b001, ADD = 3'b010, SUB = 3'b110, SLT = 3'b111;

	wire [`DATA_WIDTH - 1:0] A_switched, B_switched, res_sum, res_and, res_or;
	wire cin, cout;
	wire A_sign, B_sign, sum_sign;  /* signal bit */

	b32_adder ALU_adder (
		.A(A_switched), .B(B_switched), .cin(cin), .cout(cout), .S(res_sum)
	);

	assign Zero = ~|Result;
	assign A_switched = (ALUop == SLT ? { ~A_sign,A[`DATA_WIDTH - 2:0] } : A);  /* use shift code when SLT */
	assign B_switched = (ALUop == SUB ? ~B : (ALUop == SLT ? ~{ ~B_sign,B[`DATA_WIDTH - 2:0] } : B));
	assign cin = (ALUop == SUB || ALUop == SLT ? 1'b1 : 1'b0);

	assign res_and = A & B;
	assign res_or = A | B;

	assign A_sign = A[`DATA_WIDTH - 1];
	assign B_sign = B[`DATA_WIDTH - 1];
	assign sum_sign = res_sum[`DATA_WIDTH - 1];

	assign Overflow = (A_switched[`DATA_WIDTH - 1] == B_switched[`DATA_WIDTH - 1] && A_switched[`DATA_WIDTH - 1] != sum_sign);
	assign CarryOut = (ALUop == ADD && cout == 1'b1) || (ALUop == SUB && cout == 1'b0);

	assign Result = (
		ALUop == AND ? res_and : (
		ALUop == OR ? res_or : (
		ALUop == ADD || ALUop == SUB ? res_sum : (
		ALUop == SLT ? { 31'd0,~cout } : 32'd0
	))));
endmodule

module b32_adder(
	input	[`DATA_WIDTH - 1:0]	A,
	input	[`DATA_WIDTH - 1:0]	B,
	input						cin,
	output						cout,
	output	[`DATA_WIDTH - 1:0] S
);
	assign { cout,S } = A + B + cin;
endmodule
