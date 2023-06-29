`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Xu Zhang (zhangxu415@mails.ucas.ac.cn)
// 
// Create Date: 06/14/2018 11:39:09 AM
// Design Name: 
// Module Name: dma_core
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module engine_core #(
	parameter integer  DATA_WIDTH       = 32
)
(
	input    clk,
	input    rst,
	
	output reg [31:0]       src_base,
	output reg [31:0]       dest_base,
	output reg [31:0]       tail_ptr,
	output reg [31:0]       head_ptr,
	output reg [31:0]       dma_size,
	output reg [31:0]       ctrl_stat,

	input  [31:0]	    reg_wr_data,
	input  [ 5:0]       reg_wr_en,
  
	output              intr,
  
	output [31:0]       rd_req_addr,
	output [ 4:0]       rd_req_len,
	output              rd_req_valid,
	
	input               rd_req_ready,
	input  [31:0]       rd_rdata,
	input               rd_last,
	input               rd_valid,
	output              rd_ready,
	
	output [31:0]       wr_req_addr,
	output [ 4:0]       wr_req_len,
	output              wr_req_valid,
	input               wr_req_ready,
	output [31:0]       wr_data,
	output              wr_valid,
	input               wr_ready,
	output              wr_last,
	
	output reg          fifo_rden,
	output [31:0]       fifo_wdata,
	output              fifo_wen,

	input  [31:0]       fifo_rdata,
	input               fifo_is_empty,
	input               fifo_is_full
);
	// TODO: Please add your logic design here

	reg [26:0] Burst_ymr;	/* Counter of Burst */
	reg [4:0] Send_ymr;		/* Counter of sending of every Burst */
	reg [31:0] sub_ptr;		/* Points to the address of current Burst */

	reg [31:0] FFR;	/* FIFO reg, which holds data read from it */

	reg [5:0] current_state, next_state;
	reg IFR;	/* Initial flag reg */

	reg EFR;	/* Error flag reg. For DEBUG! */

	/* For FSM */
	localparam s_WAIT = 6'h1, s_LOAD = 6'h2, s_RECV = 6'h4,
		s_STOR = 6'h8, s_FFRD = 6'h10, s_SEND = 6'h20;

	/* reg writing signals */
	localparam w_SRC = 6'b000001, w_DEST = 6'b000010, w_TAIL = 6'b000100,
		w_HEAD = 6'b001000, w_SIZE = 6'b010000, w_CTRL = 6'b100000;

	/* FSM: 1 */
	always @ (posedge clk) begin
		if (rst)
			current_state <= s_WAIT;
		else
			current_state <= next_state;
	end

	/* FSM: 2 */
	always @ (*) begin
		case (current_state)
		s_WAIT:
			if (ctrl_stat[0] && head_ptr != tail_ptr &&
			/* DMA::EN */
				!intr && dma_size != 32'd0 && !IFR)
				next_state = s_LOAD;
			else
				next_state = s_WAIT;
		s_LOAD:
			if (rd_req_ready)
				next_state = s_RECV;
			else
				next_state = s_LOAD;
		s_RECV:
			if (rd_valid && rd_last)
				next_state = s_STOR;
			else
				next_state = s_RECV;
		s_STOR:
			if (wr_req_ready)
				next_state = s_FFRD;
			else
				next_state = s_STOR;
		s_FFRD:
			if (fifo_rden == 0)
				next_state = s_SEND;
			else
				next_state = s_FFRD;
		default:	/* s_SEND */
			if (!wr_ready)
				next_state = s_SEND;
			else begin	/* wr_ready */
				if (Send_ymr != wr_req_len)
					/* one burst has not finished */
					next_state = s_FFRD;
				else if (Burst_ymr == dma_size[31:5])
					/* one sub buffer has finished */
					next_state = s_WAIT;
				else	/* next sub buffer */
					next_state = s_LOAD;
			end
		endcase
	end

	assign intr = ctrl_stat[31];

	/* IFR */
	always @ (posedge clk) begin
		IFR <= rst;
	end

	/* src_base */
	always @ (posedge clk) begin
		if (rst)
			src_base <= 32'd0;
		else if (reg_wr_en == w_SRC)
			/* CPU writes */
			src_base <= reg_wr_data;
	end

	/* dest_base */
	always @ (posedge clk) begin
		if (rst)
			dest_base <= 32'd0;
		else if (reg_wr_en == w_DEST)
			dest_base <= reg_wr_data;
	end

	/* tail_ptr */
	always @ (posedge clk) begin
		if (rst)
			tail_ptr <= 32'd0;
		else if (reg_wr_en == w_TAIL)
			tail_ptr <= reg_wr_data;
		else if (current_state == s_SEND && next_state == s_WAIT)
			/* One sub buffer has been finished */
			tail_ptr <= { tail_ptr[31:5] + Burst_ymr,5'd0 };
	end

	/* head_ptr */
	always @ (posedge clk) begin
		if (rst)
			head_ptr <= 32'd0;
		else if (reg_wr_en == w_HEAD)
			head_ptr <= reg_wr_data;
	end

	/* dma_size */
	always @ (posedge clk) begin
		if (rst)
			dma_size <= 32'd0;
		else if (reg_wr_en == w_SIZE)
			dma_size <= reg_wr_data;
	end

	/* ctrl_stat */
	always @ (posedge clk) begin
		if (rst)
			ctrl_stat <= 32'd0;
		else if (reg_wr_en == w_CTRL)
			ctrl_stat <= reg_wr_data;
		else if (current_state == s_SEND && next_state == s_WAIT)
			/* Set interrupt signal */
			ctrl_stat <= { 1'd1,ctrl_stat[30:0] };
	end

	/* sub_ptr */
	always @ (posedge clk) begin
		if (rst)
			sub_ptr <= 32'd0;
		else if (next_state == s_LOAD) begin
			if (current_state == s_WAIT)
				/* new sub buffer */
				sub_ptr <= tail_ptr;
			else if (current_state == s_SEND)
				/* new Burst */
				sub_ptr <= sub_ptr + 32'd32;
		end
	end

	/* FFR */
	always @ (posedge clk) begin
		if (current_state == s_FFRD && next_state == s_SEND)
			FFR <= fifo_rdata;
	end

	/* fifo_rden */
	always @ (posedge clk) begin
		if (rst || fifo_rden)
			fifo_rden <= 0;
		else if (next_state == s_FFRD && fifo_rden == 0)
			fifo_rden <= 1;
	end

	/* Connect to main memory */
	assign rd_req_addr = src_base + sub_ptr, wr_req_addr = dest_base + sub_ptr,
		rd_req_len = 5'd7, wr_req_len = 5'd7,
		rd_ready = (IFR || current_state == s_RECV),
		wr_data = FFR, wr_valid = (current_state == s_SEND),
		wr_last = (wr_valid && Send_ymr == wr_req_len),
		rd_req_valid = (current_state == s_LOAD), wr_req_valid = (current_state == s_STOR);

	/* Connect to FIFO */
	assign fifo_wdata = rd_rdata,
		fifo_wen = (current_state == s_RECV && rd_valid && rd_ready);

	/* Send_ymr */
	always @ (posedge clk) begin
		if (current_state == s_STOR)
			Send_ymr <= 5'd0;
		else if (current_state == s_SEND && next_state == s_FFRD)
			Send_ymr <= Send_ymr + 5'd1;
	end

	/* Burst_ymr */
	always @ (posedge clk) begin
		if (rst || next_state == s_WAIT)
			Burst_ymr <= 27'd0;
		else if (current_state != s_LOAD && next_state == s_LOAD)
			/* Begin a new Burst */
			Burst_ymr <= Burst_ymr + 27'd1;
	end

	/* EFR */
	always @ (posedge clk) begin
		if (rst)
			EFR <= 0;
		else if (fifo_is_empty && fifo_rden ||
			fifo_is_full && fifo_wen)
			/* Error occurs */
			EFR <= 1;
	end
endmodule
