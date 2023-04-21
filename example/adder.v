`timescale 10ns / 1ns

module adder (
	input  [7:0] operand0,
	input  [7:0] operand1,
	output reg [7:0] result
);

	/*TODO: Please add your logic design here*/
	always @ (*)
	begin
		result = operand0 + operand1;
	end

	initial begin
		#20
		$display("I am an iKun!\n");
	end

endmodule
