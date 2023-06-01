`timescale 10ns / 1ns

/* Writing back stage */
module stage_WB(
	input clk,
	input rst,

	/* Connect to last stage */
	input [31:0] PC_I,
	input Done_I,
	input [4:0] RF_waddr,
	input [31:0] RF_wdata,

	/* Connect to Regfile */
	output RF_wen,
	/* NOTE: WAddr and Wdata of Regfile
	just use the two input signals above */

	/* Terminus */
	/* inst retire reg */
	output [69:0] IRR
);


endmodule