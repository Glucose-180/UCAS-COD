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
	reg [31:0] lsub_ptr, ssub_ptr;		/* Points to the address of current Burst */

	reg [31:0] FFR;	/* FIFO reg, which holds data read from it */
	reg [15:0] FIFO_ymr;	/* FIFO counter */

	reg [3:0] load_state, load_next;
	reg [3:0] store_state, store_next;
	reg IFR;	/* Initial flag reg */

	reg EFR;	/* Error flag reg. For DEBUG! */

	/* For FSM */
	localparam ls_WAIT = 4'h1, ls_LOAD = 4'h2,
		ls_RECV = 4'h4, ls_DONE = 4'h8;	/* Loading engine */
	localparam ss_WAIT = 4'h1, ss_STOR = 4'h2,
		ss_FFRD = 4'h4, ss_SEND = 4'h8;	/* Storing engine */

	/* reg writing signals */
	localparam w_SRC = 6'b000001, w_DEST = 6'b000010, w_TAIL = 6'b000100,
		w_HEAD = 6'b001000, w_SIZE = 6'b010000, w_CTRL = 6'b100000;

	/* FSM: 1 */
	always @ (posedge clk) begin
		if (rst)
			load_state <= ls_WAIT;
		else
			load_state <= load_next;
	end
	always @ (posedge clk) begin
		if (rst)
			store_state <= ss_WAIT;
		else
			store_state <= store_next;
	end

	/* FSM: 2 */
	always @ (*) begin
		case (load_state)
		ls_WAIT:
			if (ctrl_stat[0] && head_ptr != tail_ptr &&
			/* DMA::EN */
				/*!intr && */dma_size != 32'd0 && !IFR)
				load_next = ls_LOAD;
			else
				load_next = ls_WAIT;
		ls_LOAD:
			if (rd_req_ready)
				load_next = ls_RECV;
			else
				load_next = ls_LOAD;
		ls_RECV:
			if (!(rd_valid && rd_last && rd_ready))
				load_next = ls_RECV;
			else begin
				if (Burst_ymr == dma_size[31:5])
				/* One sub buffer has been finished */
					load_next = ls_DONE;
				else
					load_next = ls_LOAD;
			end
		default:	/* ls_DONE, wait for storing engine */
			if (fifo_is_empty)
				/* FIFO is empty */
				load_next = ls_WAIT;
			else
				load_next = ls_DONE;
		endcase
	end
	always @ (*) begin
		case (store_state)
		ss_WAIT:
			if (!IFR && FIFO_ymr[15:3] != 13'd0)
				/* FIFO_ymr >= 8 */
				store_next = ss_STOR;
			else
				store_next = ss_WAIT;
		ss_STOR:
			if (wr_req_ready)
				store_next = ss_FFRD;
			else
				store_next = ss_STOR;
		ss_FFRD:
			if (fifo_rden == 0)
				store_next = ss_SEND;
			else
				store_next = ss_FFRD;
		default:	/* ss_SEND */
			if (!wr_ready)
				store_next = ss_SEND;
			else begin
				if (Send_ymr != wr_req_len)
					store_next = ss_FFRD;
				else
					store_next = ss_WAIT;
			end
		endcase
	end

	assign intr = ctrl_stat[31];

	/* FIFO_ymr */
	always @ (posedge clk) begin
		FIFO_ymr <= FIFO_ymr + (
			{16{fifo_wen && !fifo_is_full}} & 16'd1 |	/* inc */
			{16{fifo_rden && !fifo_is_empty}} & ~16'd0	/* dec */
		);
	end

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
		else if (load_state == ls_DONE && load_next == ss_WAIT)
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
		else if (load_state == ls_DONE && load_next == ss_WAIT)
			/* Set interrupt signal */
			ctrl_stat <= { 1'd1,ctrl_stat[30:0] };
	end

	/* lsub_ptr */
	always @ (posedge clk) begin
		if (rst)
			lsub_ptr <= 32'd0;
		else if (load_next == ls_LOAD) begin
			if (load_state == ls_WAIT)
				/* new sub buffer */
				lsub_ptr <= tail_ptr;
				/* new Burst */
			else if (load_state == ls_RECV)
				lsub_ptr <= lsub_ptr + 32'd32;
		end
	end

	/* ssub_ptr */
	always @ (posedge clk) begin
		if (rst)
			ssub_ptr <= 32'd0;
		else if (store_state == ss_SEND && store_next == ss_WAIT)
			/* new Burst */
			ssub_ptr <= ssub_ptr + 32'd32;
	end

	/* FFR */
	always @ (posedge clk) begin
		if (store_state == ss_FFRD && store_next == ss_SEND)
			FFR <= fifo_rdata;
	end

	/* fifo_rden */
	always @ (posedge clk) begin
		if (rst || fifo_rden)
			fifo_rden <= 0;
		else if (store_next == ss_FFRD && fifo_rden == 0)
			fifo_rden <= 1;
	end

	/* Connect to main memory */
	assign rd_req_addr = src_base + lsub_ptr, wr_req_addr = dest_base + ssub_ptr,
		rd_req_len = 5'd7, wr_req_len = 5'd7,
		/* Only when FIFO is not full can rd_ready be 1 */
		rd_ready = (IFR || load_state == ls_RECV && !fifo_is_full),
		wr_data = FFR, wr_valid = (store_state == ss_SEND),
		wr_last = (wr_valid && Send_ymr == wr_req_len),
		rd_req_valid = (load_state == ls_LOAD), wr_req_valid = (store_state == ss_STOR);

	/* Connect to FIFO */
	assign fifo_wdata = rd_rdata,
		fifo_wen = (load_state == ls_RECV && rd_valid && rd_ready);

	/* Send_ymr */
	always @ (posedge clk) begin
		if (store_state == ss_STOR)
			/* clear */
			Send_ymr <= 5'd0;
		else if (store_state == ss_SEND && store_next == ss_FFRD)
			Send_ymr <= Send_ymr + 5'd1;
	end

	/* Burst_ymr */
	always @ (posedge clk) begin
		if (rst || load_next == ls_WAIT)
			Burst_ymr <= 27'd0;
		else if (load_state != ls_LOAD && load_next == ls_LOAD)
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
