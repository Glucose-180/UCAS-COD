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
	parameter AND = 3'b000, OR = 3'b001, ADD = 3'b010, SUB = 3'b110, SLT = 3'b111, XOR = 3'b100, NOR = 3'b101, SLTU = 3'b011;

	wire [`DATA_WIDTH - 1:0] A_switched, B_switched, res_sum, res_and, res_or, res_xor, res_nor;
	wire cin, cout;
	wire A_sign, B_sign, sum_sign;  /* signal bit */
	wire opAND, opOR, opADD, opSUB, opSLT, opXOR, opNOR, opSLTU;

	assign { cout,res_sum } = A_switched + B_switched + cin;

	assign { opAND,opOR,opADD,opSUB,opSLT,opXOR,opNOR,opSLTU } = { ALUop == AND,ALUop == OR,ALUop == ADD,ALUop == SUB,ALUop == SLT,ALUop == XOR,ALUop == NOR,ALUop == SLTU };

	assign Zero = ~|Result;
	assign A_switched = (opSLT ? { ~A_sign,A[`DATA_WIDTH - 2:0] } : A);  /* use shift code when SLT */
	assign B_switched = (opSUB || opSLTU ? ~B : (opSLT ? ~{ ~B_sign,B[`DATA_WIDTH - 2:0] } : B));
	assign cin = (opSUB || opSLT || opSLTU ? 1'b1 : 1'b0);

	assign res_and = A & B;
	assign res_or = A | B;
	assign res_xor = A ^ B;
	assign res_nor = ~res_or;

	assign A_sign = A[`DATA_WIDTH - 1];
	assign B_sign = B[`DATA_WIDTH - 1];
	assign sum_sign = res_sum[`DATA_WIDTH - 1];

	assign Overflow = (A_sign == B_switched[`DATA_WIDTH - 1] && A_sign != sum_sign);
	assign CarryOut = (opADD && cout) || (opSUB && ~cout);

	assign Result = (
		{`DATA_WIDTH{opAND}} & res_and |
		{`DATA_WIDTH{opOR}} & res_or |
		{`DATA_WIDTH{opXOR}} & res_xor |
		{`DATA_WIDTH{opNOR}} & res_nor |
		{`DATA_WIDTH{opADD || opSUB}} & res_sum |
		{`DATA_WIDTH{opSLT || opSLTU}} & { 31'd0,~cout }
	);
endmodule
