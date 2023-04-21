`timescale 10ns / 1ns
`define FAIL_CLOCK 50

module simple_cpu(
	input             clk,
	input             rst,

	output [31:0]     PC,
	input  [31:0]     Instruction,

	output [31:0]     Address,
	output            MemWrite,
	output [31:0]     Write_data,
	output [ 3:0]     Write_strb,

	input  [31:0]     Read_data,
	output            MemRead
);

	// THESE THREE SIGNALS ARE USED IN OUR TESTBENCH
	// PLEASE DO NOT MODIFY SIGNAL NAMES
	// AND PLEASE USE THEM TO CONNECT PORTS
	// OF YOUR INSTANTIATION OF THE REGISTER FILE MODULE
	/* For Regfile */
	wire			RF_wen;
	wire [4:0]		RF_waddr;
	wire [31:0]		RF_wdata;
	wire [31:0] RF_rdata1, RF_rdata2;
	wire [31:0] RF_wdata_ItypeR;	/* write data for Itype_r */
	wire [7:0] LoadB;
	wire [15:0] LoadH;
	wire [31:0] LoadWL, LoadWR;		/* for load Instruction */
	wire [31:0] StoreWL, StoreWR;	/* for store Instruction */

	// TODO: PLEASE ADD YOUR CODE BELOW
	/* For Instruction */
	reg [31:0] PC;
	wire [31:0] PCa4, PCa8;	/* PCa4: PC + 4 */
	wire [31:0] SE16, ZE16;	/* Instruction[15:0] is sign-extended or zero-extended */
	wire [5:0] opcode, func;

	/* Type of Instruction */
	wire Rtype, REGIMM, Jtype, Itype_branch, Itype_calc, Itype_r, Itype_w;

	/* For ALU */
	wire [31:0] ALU_A, ALU_B, ALU_res;
	wire [2:0] ALUop;
	wire ALU_OF, ALU_CF, ALU_ZF;
	/* For Control unit */
	wire RegDst, Mem2Reg, RF2ALU_B;
	/* For shifter */
	wire [4:0] SFT_B;
	wire [1:0] SFTop;
	wire [31:0] SFT_res;

	/* fail by design */
	reg [7:0] count;

	/* Instantiation of the register file module */
	reg_file REG (
		.clk(clk), .waddr(RF_waddr), .wen(RF_wen), .wdata(RF_wdata),
		.raddr1(Instruction[25:21]), .raddr2(Instruction[20:16]), .rdata1(RF_rdata1), .rdata2(RF_rdata2)
	);
	/* Instantiation of the ALU module */
	alu ALU (
		.A(ALU_A), .B(ALU_B), .ALUop(ALUop), .Overflow(ALU_OF), .CarryOut(ALU_CF), .Zero(ALU_ZF), .Result(ALU_res)
	);
	/* Instantiation of the shifter module */
	shifter SFT (
		.A(RF_rdata2), .B(SFT_B), .Shiftop(SFTop), .Result(SFT_res)
	);

	/* ALU opcode */
	parameter ALU_AND = 3'b000, ALU_OR = 3'b001, ALU_ADD = 3'b010, ALU_SUB = 3'b110, ALU_SLT = 3'b111, ALU_XOR = 3'b100, ALU_NOR = 3'b101, ALU_SLTU = 3'b011;
	/* Instruction opcode */
	parameter OC_addiu = 6'b001001, OC_lui = 6'b001111, OC_andi = 6'b001100, OC_ori = 6'b001101, OC_xori = 6'b001110, OC_slti = 6'b001010, OC_sltiu = 6'b001011, OC_jal = 6'b000011;
	/* R-type func */
	parameter FC_addu = 6'b100001, FC_subu = 6'b100011, FC_and = 6'b100100, FC_or = 6'b100101, FC_xor = 6'b100110, FC_nor = 6'b100111, FC_slt = 6'b101010, FC_sltu = 6'b101011, FC_jr = 6'b001000, FC_jalr = 6'b001001;

	assign PCa4 = PC + 32'd4;
	assign PCa8 = PC + 32'd8;
	assign SE16 = { {16{Instruction[15]}},Instruction[15:0] };
	assign ZE16 = { 16'd0,Instruction[15:0] };
	assign opcode = Instruction[31:26];
	assign func = Instruction[5:0];

	/* count */
	always @ (posedge clk)
		if (rst != 1'b0)
			count <= 8'd0;
		else
			count <= count + 1;

	/* PC */
	always @ (posedge clk)
		if (rst != 1'b0)
			PC <= 32'd0;		/* Reset */
		else if (count >= `FAIL_CLOCK)
			PC <= 32'd0;		/* Fail by design */
		else begin
			if (Rtype && (func == FC_jr || func == FC_jalr))
				PC <= RF_rdata1;	/* [jr], [jalr] */
			else if ((REGIMM && (Instruction[16] ^ RF_rdata1[31])) ||
					(Itype_branch && opcode[1] == 1'b0 && (ALU_ZF ^ opcode[0])) ||
					Itype_branch && opcode[1] == 1'b1 && (opcode[0] ^ (ALU_res[31] || ALU_ZF)))
				PC <= PCa4 + (SE16 << 2);
				/* [bltz], [bgez]; [beq], [bne]; [blez], [bgtz] */
			else if (Jtype)
				PC <= { PCa4[31:28],Instruction[25:0],2'b00 };	/* [j], [jal] */
			else
				PC <= PCa4;
		end

	/* Control unit */
	assign { Rtype,REGIMM,Jtype,Itype_branch,Itype_calc,Itype_r,Itype_w } = {
		opcode == 6'b000000, opcode == 6'b000001, opcode[5:1] == 5'b00001,
		opcode[5:2] == 4'b0001, opcode[5:3] == 3'b001,
		opcode[5:3] == 3'b100, opcode[5:3] == 3'b101
	};
	assign RegDst = ~(Itype_calc || Itype_r || Itype_w);
	assign MemRead = Itype_r;
	assign Mem2Reg = Itype_r;
	assign MemWrite = Itype_w;
	assign RF2ALU_B = (Rtype && func[5] == 1 || Itype_branch);

	/* Regfile */
	assign RF_waddr = (Jtype ? 5'd31 : ({5{RegDst}} & Instruction[15:11] | ~{5{RegDst}} & Instruction[20:16]));
	assign RF_wen = ((Rtype && func[5:1] != 5'b00101 && func != FC_jr || Rtype && func[5:1] == 5'b00101 && (|RF_rdata2) == func[0]) || (opcode == OC_jal) || Itype_calc || Itype_r);
	/* Rtype except [movz], [movn] and [jr]; [movz], [movn]; [jal]; Itype_calc; Itype_r */
	assign RF_wdata = (
		{32{Rtype && func[5] == 1 || Itype_calc}} & ALU_res |
		/* Rtype::calc, Itype_calc */
		{32{Rtype && func[5:3] == 3'b000}} & SFT_res |
		/* Rtype::shift */
		{32{Rtype && { func[5:3],func[1] } == 4'b0010 || Jtype}} & PCa8 |
		/* Rtype::jump, Jtype */
		{32{Rtype && { func[5:3],func[1] } == 4'b0011}} & RF_rdata1 |
		/* Rtype::mov */
		{32{Itype_r}} & RF_wdata_ItypeR
		/* Itype_r */
	);
	assign RF_wdata_ItypeR = (
		{32{opcode[1:0] == 2'b00}} & { (opcode[2] ? 24'd0 : {24{LoadB[7]}}),LoadB } |
		/* [lbu], [lb] */
		{32{opcode[1:0] == 2'b01}} & { (opcode[2] ? 16'd0 : {16{LoadH[15]}}),LoadH } |
		/* [lhu], [lh] */
		{32{opcode[1:0] == 2'b11}} & Read_data |
		/* [lw] */
		{32{opcode[1:0] == 2'b10}} & (opcode[2] ? LoadWR : LoadWL)
		/* [lwr], [lwl] */
	);
	assign LoadB = Read_data[ALU_res[1:0] * 8 +: 8];
	assign LoadH = Read_data[ALU_res[1] * 16 +: 16];
	assign LoadWL = (
		{32{ALU_res[1:0] == 2'b00}} & { Read_data[7:0],RF_rdata2[23:0] } |
		{32{ALU_res[1:0] == 2'b01}} & { Read_data[15:0],RF_rdata2[15:0] } |
		{32{ALU_res[1:0] == 2'b10}} & { Read_data[23:0],RF_rdata2[7:0] } |
		{32{ALU_res[1:0] == 2'b11}} & Read_data
	);
	assign LoadWR = (
		{32{ALU_res[1:0] == 2'b00}} & Read_data |
		{32{ALU_res[1:0] == 2'b01}} & { RF_rdata2[31:24],Read_data[31:8] } |
		{32{ALU_res[1:0] == 2'b10}} & { RF_rdata2[31:16],Read_data[31:16] } |
		{32{ALU_res[1:0] == 2'b11}} & { RF_rdata2[31:8],Read_data[31:24] }
	);

	/* ALU */
	assign ALU_A = RF_rdata1;
	assign ALU_B = (RF2ALU_B ? RF_rdata2 : (
		{32{Itype_r || Itype_w || opcode == OC_addiu || opcode == OC_slti || opcode == OC_sltiu}} & SE16 |
		/* Itype_r, Itype_w, [addiu], [slti], [sltiu] */
		{32{opcode == OC_andi || opcode == OC_ori || opcode == OC_xori}} & ZE16 |
		/* [andi], [ori], [xori] */
		{32{opcode == OC_lui}} & (ZE16 << 16)
		/* [lui] */
	));
	assign ALUop = (
		{3{Rtype && func == FC_addu || opcode == OC_addiu || Itype_r || Itype_w}} & ALU_ADD |
		/* [addu], [addiu], Itype_r, Itype_w */
		{3{Rtype && func == FC_subu || Itype_branch}} & ALU_SUB |
		/* [subu], Itype_branch */
		{3{Rtype && func == FC_and || opcode == OC_andi}} & ALU_AND |
		/* [and], [andi] */
		{3{Rtype && func == FC_or || opcode == OC_ori || opcode == OC_lui}} & ALU_OR |
		/* [or], [ori], [lui] */
		{3{Rtype && func == FC_xor || opcode == OC_xori}} & ALU_XOR |
		/* [xor], [xori] */
		{3{Rtype && func == FC_nor}} & ALU_NOR |
		/* [nor] */
		{3{Rtype && func == FC_slt || opcode == OC_slti}} & ALU_SLT |
		/* [slt], [slti] */
		{3{Rtype && func == FC_sltu || opcode == OC_sltiu}} & ALU_SLTU
		/* [sltu], [sltiu] */
	);

	/* shifter */
	assign SFT_B = {5{Rtype && func[5:2] == 4'b0000}} & Instruction[10:6] | {5{Rtype && func[5:2] == 4'b0001}} & RF_rdata1[4:0];
	assign SFTop = func[1:0];

	/* RAM */
	assign Address = { ALU_res[31:2],2'b0 };
	assign Write_data = {
		/*{32{opcode[1:0] == 2'b00}} & (RF_rdata2 << { ALU_res[1:0],3'd0 }) |	// [sb]
		{32{opcode[1:0] == 2'b01}} & (RF_rdata2 << { ALU_res[1],4'd0 }) |	// [sh]*/
		{32{opcode[1] == 0}} & (RF_rdata2 << { ALU_res[1:0],3'd0 }) |
		/* [sb], [sh] */
		{32{opcode[1:0] == 2'b11}} & RF_rdata2 |
		/* [sw] */
		{32{opcode[1:0] == 2'b10}} & (opcode[2] ? StoreWR : StoreWL)
		/* [swr], [swl] */
	};
	assign StoreWL = (
		{32{ALU_res[1:0] == 2'b00}} & { 24'd0,RF_rdata2[31:24] } |
		{32{ALU_res[1:0] == 2'b01}} & { 16'd0,RF_rdata2[31:16] } |
		{32{ALU_res[1:0] == 2'b10}} & { 8'd0,RF_rdata2[31:8] } |
		{32{ALU_res[1:0] == 2'b11}} & RF_rdata2
	);
	assign StoreWR = (
		{32{ALU_res[1:0] == 2'b00}} & RF_rdata2 |
		{32{ALU_res[1:0] == 2'b01}} & { RF_rdata2[23:0],8'd0 } |
		{32{ALU_res[1:0] == 2'b10}} & { RF_rdata2[15:0],16'd0 } |
		{32{ALU_res[1:0] == 2'b11}} & { RF_rdata2[7:0],24'd0 }
	);
	assign Write_strb = (
		{4{opcode[1:0] == 2'b00}} & (4'd1 << ALU_res[1:0]) |
		/* [sb] */
		{4{opcode[1:0] == 2'b01}} & (4'd3 << ALU_res[1:0]) |
		/* [sh] */
		{4{opcode[1:0] == 2'b11}} & 4'd15 |
		/* [sw] */
		{4{opcode[1:0] == 2'b10}} & (opcode[2] ? (4'd15 << ALU_res[1:0]) : ~(4'd14 << ALU_res[1:0]))
	);
endmodule
