`timescale 10ns / 1ns

/* Execute stage */
module stage_EX(
	input clk_I,
	input rst,

	/* Connect to last stage */
	/* Decode result */
	input [19:0] Decode_res,
	/* Regfile read data */
	input [31:0] RF_rdata1,
	input [31:0] RF_rdata2,
	input Done_I,
	input [31:0] PC_I,
	/* Regfile write address */
	input [4:0] RF_wdata,
	input [31:0] Imm,

	/* Connect to next stage */
	output reg [31:0] PC_O,
	output reg Done_O,
	/* Memory control reg:
	MemR, MemW and Write_strb */
	output reg [5:0] MCR,
	/* Mem write data */
	output reg [31:0] WDR,
	/* ALU, SFT reg, also holds
	Mem write address */
	output reg [31:0] ASR,
	/* Regfile write address */
	output reg [4:0] RAR,
	/* Funct3 */
	output reg [2:0] F3R,

	/* Feedback */
	output wire Feedback_Branch,
	input wire Feedback_Mem_Acc
);

	wire clk;

	/* For ALU and shifter */
	wire [31:0] ALU_A, ALU_B, ALU_res;
	wire [2:0] ALUop;
	wire ALU_ZF, ALU_CF, ALU_OF;
	wire [31:0] SFT_A, SFT_B, SFT_res;
	wire [1:0] SFTop;

	wire [2:0] Funct3;

	wire [3:0] Write_strb;

	/* For MUL instruction */
	wire [63:0] Product;
	
	/* Effective clock */
	assign clk = (clk_I & (rst | ~Feedback_Mem_Acc));

	assign Funct3 = Decode_res[18:16];

	/* ALU */
	assign ALUop = Decode_res[4:2],
		ALU_A = (Decode_res[12] || Decode_res[10] || Decode_res[8] ? PC_I : RF_rdata1),
		/* Itype_J, Utype, Jtype */
		ALU_B = (
			{32{Decode_res[15] || Decode_res[9]}} & RF_rdata2 |
			/* Rtype, Btype */
			{32{Decode_res[14] || Decode_res[13] || Decode_res[11] || Decode_res[10]}} & Imm |
			/* Itype_CS, Itype_L, Stype, Utype */
			{32{Decode_res[8] || Decode_res[12]}} & 32'd4
			/* Jtype, Itype_J */
		);
	
	/* SFT */
	assign SFTop = Decode_res[1:0],
		SFT_A = RF_rdata1,
		SFT_B = (
		{5{Decode_res[15]}} & RF_rdata2[4:0] |	/* Rtype */
		{5{Decode_res[14]}} & Imm[4:0]		/* Itype_CS */
	);

	/* Instantiation of the ALU module */
	alu ALU (
		.A(ALU_A), .B(ALU_B), .ALUop(ALUop), .Overflow(ALU_OF),
		.CarryOut(ALU_CF), .Zero(ALU_ZF), .Result(ALU_res)
	);
	/* Instantiation of the shifter module */
	shifter SFT (
		.A(SFT_A), .B(SFT_B), .Shiftop(SFTop), .Result(SFT_res)
	);

	assign Feedback_Branch = Done_I & (
		Decode_res[19] | /* [AUIPC] */
		Decode_res[9] & (Funct3[2] ^ Funct3[0] ^ ALU_ZF) |
		/* Btype */
		Decode_res[8] | Decode_res[12]
		/* Jtype, Itype-J */
	);

	assign Product = RF_rdata1 * RF_rdata2;

	/* Done_O */
	always @ (posedge clk) begin
		if (rst)
			Done_O <= 0;
		else
			Done_O <= Done_I;
	end

	/* MCR */
	always @ (posedge clk) begin
		if (rst)
			MCR <= 6'd0;
		else if (Done_I)
			MCR <= {
				Decode_res[11],	/* MemW */
				Decode_res[13],	/* Itype_L */
				Write_strb
			};
	end

	assign Write_strb = (
			{4{Funct3[1:0] == 2'b00}} & (4'd1 << ALU_res[1:0]) |
			/* [SB] */
			{4{Funct3[1:0] == 2'b01}} & (4'd3 << { ALU_res[1],1'd0 }) |
			/* [SH] */
			{4{Funct3[1:0] == 2'b10}} & 4'd15
			/* [SW] */
		);

	/* WDR */
	always @ (posedge clk) begin
		if (Done_I && Decode_res[11])	/* MemW */
			WDR <= (
				{32{Funct3[1:0] == 2'b00}} & (RF_rdata2 << { ALU_res[1:0],3'd0 }) |
				/* [SB] */
				{32{Funct3[1:0] == 2'b01}} & (RF_rdata2 << { ALU_res[1],4'd0 }) |
				/* [SH] */
				{32{Funct3[1:0] == 2'b10}} & RF_rdata2
				/* [SW] */
			);
	end

	/* ASR */
	always @ (posedge clk) begin
		if (Done_I) begin
			if (Decode_res[19])
				/* [AUIPC] */
				ASR <= ALU_res;
			else if (Decode_res[7])
				/* [MUL] */
				ASR <= Product[31:0];
			else if (Decode_res[5])
				/* SFTtype */
				ASR <= SFT_res;
			else
				ASR <= ALU_res;
		end
	end

	/* RAR */
	always @ (posedge clk) begin
		if (rst)
			RAR <= 5'd0;
		else if (Done_I)
			RAR <= RF_wdata;
	end

	/* PC_O */
	always @ (posedge clk) begin
		if (Done_I)
			PC_O <= PC_I;
	end

	/* F3R */
	always @ (posedge clk) begin
		if (Done_I)
			F3R <= Funct3;
	end

endmodule
