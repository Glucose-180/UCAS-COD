`timescale 10 ns / 1 ns

`define DATA_WIDTH 32
`define ADDR_WIDTH 5

module reg_file(
	input                       clk,
	input  [`ADDR_WIDTH - 1:0]  waddr,
	input  [`ADDR_WIDTH - 1:0]  raddr1,
	input  [`ADDR_WIDTH - 1:0]  raddr2,
	input                       wen,
	input  [`DATA_WIDTH - 1:0]  wdata,
	output [`DATA_WIDTH - 1:0]  rdata1,
	output [`DATA_WIDTH - 1:0]  rdata2
);

	// TODO: Please add your logic design here
	
	reg [`DATA_WIDTH - 1:0] rf [31:0];
	
	always @ (posedge clk) begin
		if (wen != 0 && waddr != 0)
			rf[waddr] <= wdata;
	end

	assign rdata1 = (raddr1 == 0 ? 32'd0 : rf[raddr1]);
	assign rdata2 = (raddr2 == 0 ? 32'd0 : rf[raddr2]);

endmodule
