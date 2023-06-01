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
	output reg [69:0] IRR
);

	assign RF_wen = (Done_I && (RF_waddr != 5'd0));

	/* IRR */
	always @ (posedge clk) begin
		if (rst)
			IRR <= 70'd0;
		else if (Done_I)
			IRR <= {
/* 69 */		RF_wen,
/* 68~64 */		RF_waddr,
/* 63~32 */		RF_wdata,
/* 31~0 */		PC_I
			};
		else	/* Done_I == 0 */
			IRR <= 70'd0;
		/* For every instruction,
		the IRR signal only exists one cycle! */
	end

endmodule