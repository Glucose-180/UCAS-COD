`timescale 10ns / 1ns
`define FAIL_CLOCK 100

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
	reg [31:0] PC, IR;		/* Program Counter, Instruction Register */
	wire [31:0] SE16, ZE16;	/* IR[15:0] is sign-extended or zero-extended */
	wire [5:0] opcode, func;

	/* Type of Instruction */
	wire NOP, Rtype, REGIMM, Jtype, Itype_branch, Itype_calc, Itype_r, Itype_w;

	/* For ALU */
	wire [31:0] ALU_A, ALU_A_ex, ALU_B, ALU_B_ex, ALU_res;
	wire [2:0] ALUop, ALUop_ex;
	wire ALU_OF, ALU_CF, ALU_ZF;
	/* For Control unit */
	wire RegDst, RF2ALU_B;
	/* For shifter */
	wire [4:0] SFT_B;
	wire [1:0] SFTop;
	wire [31:0] SFT_res;
	reg [31:0] RF_wbuf;	/* Regfile write buffer, also result register of ALU and SFT */
	reg BF;			/* flag of branch */
	/* For FSM */
	reg [5:0] current_state, next_state;

	/* fail by design */
	reg [7:0] count;

	/* Instantiation of the register file module */
	reg_file REG (
		.clk(clk), .waddr(RF_waddr), .wen(RF_wen), .wdata(RF_wdata),
		.raddr1(IR[25:21]), .raddr2(IR[20:16]), .rdata1(RF_rdata1), .rdata2(RF_rdata2)
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
	parameter OC_addiu = 6'b001001, OC_lui = 6'b001111, OC_andi = 6'b001100, OC_ori = 6'b001101, OC_xori = 6'b001110, OC_slti = 6'b001010, OC_sltiu = 6'b001011, OC_j = 6'b000010, OC_jal = 6'b000011;
	/* R-type func */
	parameter FC_addu = 6'b100001, FC_subu = 6'b100011, FC_and = 6'b100100, FC_or = 6'b100101, FC_xor = 6'b100110, FC_nor = 6'b100111, FC_slt = 6'b101010, FC_sltu = 6'b101011, FC_jr = 6'b001000, FC_jalr = 6'b001001;
	/* FSM state code */
	parameter s_IF = 5'b00001, s_ID = 5'b00010, s_EX = 5'b00100, s_MA = 5'b01000, s_WB = 5'b10000;

	assign SE16 = { {16{IR[15]}},IR[15:0] };
	assign ZE16 = { 16'd0,IR[15:0] };
	assign opcode = IR[31:26];
	assign func = IR[5:0];

	/* count */
	always @ (posedge clk)
		if (rst != 1'b0)
			count <= 8'd0;
		else
			count <= count + 1;

	/* FSM: state switch */
	always @ (posedge clk)
		if (rst != 0)
			current_state <= s_IF;
		else
			current_state <= next_state;
	/* FSM: next state */
	always @ (*) begin
		case (current_state)
		s_IF:
			next_state = s_ID;
		s_ID:
			if (NOP)
				next_state = s_IF;
			else
				next_state = s_EX;
		s_EX:
			if (REGIMM || Itype_branch || opcode == OC_j)
				next_state = s_IF;
			else if (Rtype || Itype_calc || opcode == OC_jal)
				next_state = s_WB;
			else	/* Itype_r || Itype_w */
				next_state = s_MA;
		s_MA:
			if (Itype_r)
				next_state = s_WB;
			else	/* Itype_w */
				next_state = s_IF;
		default:	/* s_WB */
			next_state = s_IF;
		endcase
	end
	/* FSM: output */
	/* PC */
	always @ (posedge clk) begin
		if (rst != 0)
			PC <= 32'd0;
		else if (count >= `FAIL_CLOCK)
			PC <= 32'd0;		/* Fail by design */
		else if (current_state == s_IF)
			PC <= ALU_res;	/* PC <= PC + 4 */
		else if (current_state == s_EX) begin
			if (Rtype && (func == FC_jr || func == FC_jalr))
			/* [jr], [jalr] */
				PC <= RF_rdata1;
			else if (BF)
				PC <= ALU_res;
			else if (Jtype)
				PC <= { PC[31:28],IR[25:0],2'b00 };	/* [j], [jal] */
		end
	end
	/* IR */
	always @ (posedge clk) begin
		if (current_state == s_IF && rst == 0)
			IR <= Instruction;
	end
	/* RF_buf */
	always @ (posedge clk) begin
		if (current_state == s_EX) begin
			if (Rtype && func[5] == 1 || Itype_calc || Itype_r || Itype_w)
				/* Rtype::calc, Itype_calc, Itype_r, Itype_w */
				RF_wbuf <= ALU_res;
			else if (Rtype && func[5:3] == 3'b000)
				/* Rtype::shift */
				RF_wbuf <= SFT_res;
			else if (Rtype && (func == FC_jr || func == FC_jalr))
				/* [jr], [jalr] */
				RF_wbuf <= ALU_res;
			else if (Rtype && { func[5:3],func[1] } == 4'b0011)
				/* Rtype::mov */
				RF_wbuf <= RF_rdata1;
			else if (Jtype || Itype_r || Itype_w)
				RF_wbuf <= ALU_res;
		end
		else if (current_state == s_MA)
			if (Itype_r)
				RF_wbuf <= RF_wdata_ItypeR;
	end
	/* BF */
	always @ (posedge clk) begin
		if (rst != 0)
			BF <= 0;
		else if (current_state == s_ID)
			BF <= ((REGIMM && (IR[16] ^ RF_rdata1[31])) ||
			(Itype_branch && opcode[1] == 1'b0 && (ALU_ZF ^ opcode[0])) ||
			Itype_branch && opcode[1] == 1'b1 && (opcode[0] ^ (ALU_res[31] || ALU_ZF)));
			/* [bltz], [bgez]; [beq], [bne]; [blez], [bgtz] */
		else if (current_state == s_EX && BF)
			BF <= 0;
	end
	assign ALU_A = (
		{32{current_state == s_IF}} & PC |
		{32{current_state == s_ID}} & RF_rdata1 |
		{32{current_state == s_EX}} & ALU_A_ex
	);
	assign ALU_B = (
		{32{current_state == s_IF}} & 32'd4 |
		{32{current_state == s_ID}} & RF_rdata2 |
		{32{current_state == s_EX}} & ALU_B_ex
	);
	assign ALUop = (
		{3{current_state == s_IF}} & ALU_ADD |
		{3{current_state == s_ID}} & ALU_SUB |
		{3{current_state == s_EX}} & ALUop_ex
	);
	assign RF_wen = (current_state == s_WB && (!Rtype || Rtype && (func != FC_jr && func[5:1] != 5'b00101 || func[5:1] == 5'b00101 && (|RF_rdata2) == func[0])));	/* not Rtype; Rtype except [jr], [movz] and [movn]; [movz], [movn] */

	/* Control unit */
	assign { NOP,Rtype,REGIMM,Jtype,Itype_branch,Itype_calc,Itype_r,Itype_w } = {
		IR == 32'd0, opcode == 6'b000000 && NOP == 0,
		opcode == 6'b000001, opcode[5:1] == 5'b00001,
		opcode[5:2] == 4'b0001, opcode[5:3] == 3'b001,
		opcode[5:3] == 3'b100, opcode[5:3] == 3'b101
	};
	assign RegDst = ~(Itype_calc || Itype_r || Itype_w);
	assign MemRead = (current_state == s_MA && Itype_r);
	assign MemWrite = (current_state == s_MA && Itype_w);
	assign RF2ALU_B = (Rtype && func[5] == 1);	/* Rtype::calc */

	/* Regfile */
	assign RF_waddr = (Jtype ? 5'd31 : ({5{RegDst}} & IR[15:11] | ~{5{RegDst}} & IR[20:16]));
	assign RF_wdata = RF_wbuf;
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
	assign LoadB = Read_data[RF_wbuf[1:0] * 8 +: 8];
	assign LoadH = Read_data[RF_wbuf[1] * 16 +: 16];
	assign LoadWL = (
		{32{RF_wbuf[1:0] == 2'b00}} & { Read_data[7:0],RF_rdata2[23:0] } |
		{32{RF_wbuf[1:0] == 2'b01}} & { Read_data[15:0],RF_rdata2[15:0] } |
		{32{RF_wbuf[1:0] == 2'b10}} & { Read_data[23:0],RF_rdata2[7:0] } |
		{32{RF_wbuf[1:0] == 2'b11}} & Read_data
	);
	assign LoadWR = (
		{32{RF_wbuf[1:0] == 2'b00}} & Read_data |
		{32{RF_wbuf[1:0] == 2'b01}} & { RF_rdata2[31:24],Read_data[31:8] } |
		{32{RF_wbuf[1:0] == 2'b10}} & { RF_rdata2[31:16],Read_data[31:16] } |
		{32{RF_wbuf[1:0] == 2'b11}} & { RF_rdata2[31:8],Read_data[31:24] }
	);

	/* ALU */
	assign ALU_A_ex = (Rtype && (func == FC_jr || func == FC_jalr) || REGIMM || Itype_branch || Jtype ? PC : RF_rdata1);
	assign ALU_B_ex = (RF2ALU_B ? RF_rdata2 : (	/* Rtype::calc */
		{32{Rtype && (func == FC_jr || func == FC_jalr) || Jtype}} & 32'd4 |
		/* Rtype::jump, Jtype */
		{32{Itype_r || Itype_w || opcode == OC_addiu || opcode == OC_slti || opcode == OC_sltiu}} & SE16 |
		/* Itype_r, Itype_w, [addiu], [slti], [sltiu] */
		{32{opcode == OC_andi || opcode == OC_ori || opcode == OC_xori}} & ZE16 |
		/* [andi], [ori], [xori] */
		{32{opcode == OC_lui}} & (ZE16 << 16) |
		/* [lui] */
		{32{REGIMM || Itype_branch}} & (SE16 << 2)
		/* REGIMM, Itype_branch */
	));
	assign ALUop_ex = (
		{3{Rtype && func == FC_addu || opcode == OC_addiu || Itype_r || Itype_w || Rtype && (func == FC_jr || func == FC_jalr) || Jtype || REGIMM || Itype_branch}} & ALU_ADD |
		/* [addu], [addiu], Itype_r, Itype_w, Rtype::jump, Jtype, REGIMM, Itype_branch */
		{3{Rtype && func == FC_subu}} & ALU_SUB |
		/* [subu] */
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
	assign SFT_B = {5{Rtype && func[5:2] == 4'b0000}} & IR[10:6] | {5{Rtype && func[5:2] == 4'b0001}} & RF_rdata1[4:0];
	assign SFTop = func[1:0];

	/* RAM */
	assign Address = { RF_wbuf[31:2],2'b0 };
	assign Write_data = {
		{32{opcode[1] == 0}} & (RF_rdata2 << { RF_wbuf[1:0],3'd0 }) |
		/* [sb], [sh] */
		{32{opcode[1:0] == 2'b11}} & RF_rdata2 |
		/* [sw] */
		{32{opcode[1:0] == 2'b10}} & (opcode[2] ? StoreWR : StoreWL)
		/* [swr], [swl] */
	};
	assign StoreWL = (
		{32{RF_wbuf[1:0] == 2'b00}} & { 24'd0,RF_rdata2[31:24] } |
		{32{RF_wbuf[1:0] == 2'b01}} & { 16'd0,RF_rdata2[31:16] } |
		{32{RF_wbuf[1:0] == 2'b10}} & { 8'd0,RF_rdata2[31:8] } |
		{32{RF_wbuf[1:0] == 2'b11}} & RF_rdata2
	);
	assign StoreWR = (
		{32{RF_wbuf[1:0] == 2'b00}} & RF_rdata2 |
		{32{RF_wbuf[1:0] == 2'b01}} & { RF_rdata2[23:0],8'd0 } |
		{32{RF_wbuf[1:0] == 2'b10}} & { RF_rdata2[15:0],16'd0 } |
		{32{RF_wbuf[1:0] == 2'b11}} & { RF_rdata2[7:0],24'd0 }
	);
	assign Write_strb = (
		{4{opcode[1:0] == 2'b00}} & (4'd1 << RF_wbuf[1:0]) |
		/* [sb] */
		{4{opcode[1:0] == 2'b01}} & (4'd3 << RF_wbuf[1:0]) |
		/* [sh] */
		{4{opcode[1:0] == 2'b11}} & 4'd15 |
		/* [sw] */
		{4{opcode[1:0] == 2'b10}} & (opcode[2] ? (4'd15 << RF_wbuf[1:0]) : ~(4'd14 << RF_wbuf[1:0]))
	);
endmodule
