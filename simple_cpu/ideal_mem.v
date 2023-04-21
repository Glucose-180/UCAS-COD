/* =========================================
* Ideal Memory Module for MIPS CPU Core
* Synchronize write (clock enable)
* Asynchronize read (do not use clock signal)
*
* Author: Yisong Chang (changyisong@ict.ac.cn)
* Date: 31/05/2016
* Version: v0.0.1
*===========================================
*/

`timescale 10 ns / 1 ns

module ideal_mem #(
	parameter ADDR_WIDTH = 14,
	parameter MEM_WIDTH = 2 ** (ADDR_WIDTH - 2)
) (
	input                      clk,        //source clock of the MIPS CPU Evaluation Module

	input  [ADDR_WIDTH - 3:0]  Waddr,      //Memory write port address
	input  [ADDR_WIDTH - 3:0]  Raddr1,     //Read port 1 address
	input  [ADDR_WIDTH - 3:0]  Raddr2,     //Read port 2 address

	input			   Wren,       //write enable
	input			   Rden1,      //port 1 read enable
	input			   Rden2,      //port 2 read enable

	input  [31:0]              Wdata,      //Memory write data
	input  [ 3:0]              Wstrb,
	output [31:0]              Rdata1,     //Memory read data 1
	output [31:0]              Rdata2      //Memory read data 2
);

reg [31:0]	mem [MEM_WIDTH - 1:0];

// Initialization of mem contents in simulation
reg [4095:0]    initmem_f;
initial
begin
	if ($value$plusargs("INITMEM=%s", initmem_f))
		$readmemh(initmem_f, mem);
end

wire [7:0]	byte_0;
wire [7:0]	byte_1;
wire [7:0]	byte_2;
wire [7:0]	byte_3;

assign byte_0 = Wstrb[0] ? Wdata[ 7: 0] : mem[Waddr][ 7: 0];
assign byte_1 = Wstrb[1] ? Wdata[15: 8] : mem[Waddr][15: 8];
assign byte_2 = Wstrb[2] ? Wdata[23:16] : mem[Waddr][23:16];
assign byte_3 = Wstrb[3] ? Wdata[31:24] : mem[Waddr][31:24];

always @ (posedge clk)
begin
	if (Wren)
		mem[Waddr] <= {byte_3, byte_2, byte_1, byte_0}; 
end

assign Rdata1 = {32{Rden1}} & mem[Raddr1];
assign Rdata2 = {32{Rden2}} & mem[Raddr2];

endmodule
