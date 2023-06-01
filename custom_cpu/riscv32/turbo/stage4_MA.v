`timescale 10ns / 1ns

/* Memory access stage */
module stage_MA(
	input clk,
	input rst,

	/* Connect to last stage */
	input [31:0] PC_I,
	input Done_I,
	/* Memory control:
	MemR, MemW and Write_strb */
	input [5:0] MCW,
	/* Mem write data */
	input [31:0] WDW,
	/* ALU, SFT result, also holds
	Mem write address */
	input [31:0] MAddr_I,
	/* Regfile write address */
	input [4:0] RWA,
	/* Funct3 */
	input [2:0] Funct3,

	/* Memory request channel */
	output [31:0] MAddr_O,
	output MemWrite,
	output [31:0] Write_data,
	output [3:0] Write_strb,
	output MemRead,
	input Mem_Req_Ready,

	/* Memory data response channel */
	input [31:0] Read_data,
	input Read_data_Valid,
	output Read_data_Ready,

	/* Connect to next stage */
	output reg [31:0] PC_O,
	output reg Done_O,
	/* Regfile write data:
	also used to deal with RAW */
	output wire [31:0] RWD,
	/* Regfile write address */
	output reg [4:0] RAR,

	/* Feedback */
	output wire Feedback_Mem_Acc
);

	localparam s_WT = 5'b00001,
		s_LD = 5'b00010, s_RDW = 5'b00100,
		s_DN = 5'b01000, s_ST = 5'b10000;

	reg [5:0] current_state, next_state;

	reg [31:0] MAR, MDR;
	/* Write strb reg */
	reg [3:0] WSR;
	/* Funct3 */
	reg [2:0] F3R;

	wire [7:0] LoadB;
	wire [15:0] LoadH;

	/* Serve as a flag of virtual initial state */
	reg IFR;

	/* FSM 1 */
	always @ (posedge clk) begin
		if (rst)
			current_state <= s_WT;
		else
			current_state <= next_state;
	end

	/* FSM 2 */
	always @ (posedge clk) begin
		case (current_state)
		s_WT:
			if (Done_I == 0)
				next_state = s_WT;
			else if (MCW[5])
				/* MemWrite */
				next_state = s_ST;
			else if (MCW[4])
				/* MemRead */
				next_state = s_LD;
			else	/* Not memory access */
				next_state = s_WT;
		s_LD:
			if (Mem_Req_Ready)
				next_state = s_RDW;
			else
				next_state = s_LD;
		s_RDW:
			if (Read_data_Valid)
				next_state = s_DN;
			else
				next_state = s_RDW;
		s_ST:
			if (Mem_Req_Ready)
				next_state = s_DN;
			else
				next_state = s_ST;
		default:	/* s_DN */
			next_state = s_WT;
		endcase
	end

	/* PC_O */
	always @ (posedge clk) begin
		if (Done_I && current_state == s_WT)
			PC_O <= PC_I;
	end

	/* WSR */
	always @ (posedge clk) begin
		if (Done_I && current_state == s_WT)
			WSR <= MCW[3:0];
	end

	/* MDR */
	always @ (posedge clk) begin
		if (Done_I && current_state == s_WT && next_state == s_ST)
			/* For Store instruction */
			MDR <= WDW;
		else if (current_state == s_RDW && next_state == s_DN)
			/* For Load instruction */
			MDR <= (
				{32{Funct3[1:0] == 2'b00}} &
					{ (Funct3[2] ? 24'd0 : {24{LoadB[7]}}),LoadB } |
				/* [LBU], [LB] */
				{32{Funct3[1:0] == 2'b01}} &
					{ (Funct3[2] ? 16'd0 : {24{LoadH[15]}}),LoadH } |
				/* [LHU], [LH] */
				{32{Funct3[1:0] == 2'b10}} & Read_data
				/* [LW] */
			);
	end

	assign LoadB = Read_data[{ MAR[1:0],3'd0 } +: 8],
		LoadH = Read_data[{ MAR[1],4'd0 } +: 16];

	/* MAR */
	always @ (posedge clk) begin
		if (Done_I && current_state == s_WT)
			MAR <= MAddr_I;
	end

	assign RWD = {32{Done_O}} & (
		(current_state == s_WT) ? MAR : MDR
		/* MAR for not memory access instruction
		MDR for Load instruction */
	);

	/* RAR */
	always @ (posedge clk) begin
		if (rst)
			RAR <= 5'd0;
		else if (Done_I && current_state == s_WT)
			RAR <= RWA;
	end

	/* F3R */
	always @ (posedge clk) begin
		if (Done_I && current_state == s_WT)
			F3R <= Funct3;
	end

	/* Done_O */
	always @ (posedge clk) begin
		if (rst)
			Done_O <= 0;
		else if (current_state == s_WT && Done_I && next_state == s_WT ||
			/* Not memory access */
			next_state == s_DN)
			/* Memory access finished */
			Done_O <= 1;
		else
			Done_O <= 0;
	end

	assign Feedback_Mem_Acc = (
		(rst != 1) &&
		(current_state != s_WT) &&
		(current_state != s_DN)
	);

	assign MAddr_O = { MAR[31:2],2'd0 };
	
	assign MemWrite = (current_state == s_ST),
		MemRead = (current_state == s_LD);

	assign Write_data = MDR,
		Write_strb = WSR;

	assign Read_data_Ready = (
		IFR || (current_state == s_RDW)
	);
	
	/* IFR */
	always @ (posedge clk) begin
		IFR <= rst;
		/* To yield a virtual initial state */
	end

endmodule