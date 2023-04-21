`timescale 10ns / 1ns

module custom_cpu(
	input         clk,
	input         rst,

	//Instruction request channel
	output reg [31:0] PC,
	output        Inst_Req_Valid,
	input         Inst_Req_Ready,

	//Instruction response channel
	input  [31:0] Instruction,
	input         Inst_Valid,
	output        Inst_Ready,

	//Memory request channel
	output [31:0] Address,
	output        MemWrite,
	output [31:0] Write_data,
	output [ 3:0] Write_strb,
	output        MemRead,
	input         Mem_Req_Ready,

	//Memory data response channel
	input  [31:0] Read_data,
	input         Read_data_Valid,
	output        Read_data_Ready,

	input         intr,

	output [31:0] cpu_perf_cnt_0,
	output [31:0] cpu_perf_cnt_1,
	output [31:0] cpu_perf_cnt_2,
	output [31:0] cpu_perf_cnt_3,
	output [31:0] cpu_perf_cnt_4,
	output [31:0] cpu_perf_cnt_5,
	output [31:0] cpu_perf_cnt_6,
	output [31:0] cpu_perf_cnt_7,
	output [31:0] cpu_perf_cnt_8,
	output [31:0] cpu_perf_cnt_9,
	output [31:0] cpu_perf_cnt_10,
	output [31:0] cpu_perf_cnt_11,
	output [31:0] cpu_perf_cnt_12,
	output [31:0] cpu_perf_cnt_13,
	output [31:0] cpu_perf_cnt_14,
	output [31:0] cpu_perf_cnt_15,

	output wire [69:0] inst_retire
);

/* The following signal is leveraged for behavioral simulation, 
* which is delivered to testbench.
*
* STUDENTS MUST CONTROL LOGICAL BEHAVIORS of THIS SIGNAL.
*
* inst_retired (70-bit): detailed information of the retired instruction,
* mainly including (in order) 
* { 
*   reg_file write-back enable  (69:69,  1-bit),
*   reg_file write-back address (68:64,  5-bit), 
*   reg_file write-back data    (63:32, 32-bit),  
*   retired PC                  (31: 0, 32-bit)
* }
*
*/
// wire [69:0] inst_retire;

// TODO: Please add your custom CPU code here

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

	/* For Instruction */
	reg [31:0] IR;		/* Instruction Register */
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
	reg [31:0] RR1, RR2;	/* Regfile register */
	/* For FSM */
	reg [8:0] current_state, next_state;

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
		.A(RR2), .B(SFT_B), .Shiftop(SFTop), .Result(SFT_res)
	);

	/* ALU opcode */
	localparam ALU_AND = 3'b000, ALU_OR = 3'b001, ALU_ADD = 3'b010, ALU_SUB = 3'b110, ALU_SLT = 3'b111, ALU_XOR = 3'b100, ALU_NOR = 3'b101, ALU_SLTU = 3'b011;
	/* Instruction opcode */
	localparam OC_addiu = 6'b001001, OC_lui = 6'b001111, OC_andi = 6'b001100, OC_ori = 6'b001101, OC_xori = 6'b001110, OC_slti = 6'b001010, OC_sltiu = 6'b001011, OC_j = 6'b000010, OC_jal = 6'b000011;
	/* R-type func */
	localparam FC_addu = 6'b100001, FC_subu = 6'b100011, FC_and = 6'b100100, FC_or = 6'b100101, FC_xor = 6'b100110, FC_nor = 6'b100111, FC_slt = 6'b101010, FC_sltu = 6'b101011, FC_jr = 6'b001000, FC_jalr = 6'b001001;
	/* FSM state code */
	localparam s_INIT = 9'h1, s_IF = 9'h2, s_IW = 9'h4, s_ID = 9'h8, s_EX = 9'h10, s_LD = 9'h20, s_RDW = 9'h40, s_ST = 9'h80, s_WB = 9'h100;

	assign SE16 = { {16{IR[15]}},IR[15:0] };
	assign ZE16 = { 16'd0,IR[15:0] };
	assign opcode = IR[31:26];
	assign func = IR[5:0];

	/* FSM: state switch */
	always @ (posedge clk)
		if (rst)
			current_state <= s_INIT;
		else
			current_state <= next_state;
	/* FSM: next state */
	always @ (*) begin
		case (current_state)
		s_INIT:	/* Initial */
			if (rst == 0)
				next_state = s_IF;
			else
				next_state = s_INIT;
		s_IF:	/* Instruction fetch */
			if (Inst_Req_Ready)
				next_state = s_IW;
			else
				next_state = s_IF;
		s_IW:	/* Instruction waiting */
			if (Inst_Valid)
				next_state = s_ID;
			else
				next_state = s_IW;
		s_ID:	/* Instruction decoding */
			if (NOP)
				next_state = s_IF;
			else
				next_state = s_EX;
		s_EX:	/* Executing */
			if (REGIMM || Itype_branch || opcode == OC_j)
				next_state = s_IF;
			else if (Rtype || Itype_calc || opcode == OC_jal)
				next_state = s_WB;
			else if (Itype_r)
				next_state = s_LD;
			else	/* Itype_w */
				next_state = s_ST;
		s_ST:	/* Storing */
			if (Mem_Req_Ready)
				next_state = s_IF;
			else
				next_state = s_ST;
		s_LD:	/* Loading */
			if (Mem_Req_Ready)
				next_state = s_RDW;
			else
				next_state = s_LD;
		s_RDW:	/* Read data waiting */
			if (Read_data_Valid)
				next_state = s_WB;
			else
				next_state = s_RDW;
		s_WB:	/* Writing back */
			next_state = s_IF;
		default:
			next_state = s_INIT;
		endcase
	end
	/* FSM: output */
	/* PC */
	always @ (posedge clk) begin
		if (rst)
			PC <= 32'd0;
		else if (current_state == s_IF)
			PC <= ALU_res;	/* PC <= PC + 4 */
		else if (current_state == s_EX) begin
			if (Rtype && (func == FC_jr || func == FC_jalr))
			/* [jr], [jalr] */
				PC <= RR1;
			else if (BF)
				PC <= ALU_res;
			else if (Jtype)
				PC <= { PC[31:28],IR[25:0],2'b00 };	/* [j], [jal] */
		end
	end
	/* IR */
	always @ (posedge clk) begin
		if (current_state == s_IW && Inst_Valid)
			IR <= Instruction;
	end
	/* RF_wbuf */
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
				RF_wbuf <= RR1;
			else if (Jtype || Itype_r || Itype_w)
				RF_wbuf <= ALU_res;
		end
		else if (current_state == s_RDW)
			if (Itype_r && Read_data_Valid)
				RF_wbuf <= RF_wdata_ItypeR;
	end
	/* BF */
	always @ (posedge clk) begin
		if (rst)
			BF <= 0;
		else if (current_state == s_ID)
			BF <= ((REGIMM && (IR[16] ^ RF_rdata1[31])) ||
			(Itype_branch && opcode[1] == 1'b0 && (ALU_ZF ^ opcode[0])) ||
			Itype_branch && opcode[1] == 1'b1 && (opcode[0] ^ (ALU_res[31] || ALU_ZF)));
			/* [bltz], [bgez]; [beq], [bne]; [blez], [bgtz] */
		else if (current_state == s_EX && BF)
			BF <= 0;
	end
	/* RR */
	always @ (posedge clk) begin
		if (current_state == s_ID)
			RR1 <= RF_rdata1;
	end
	always @ (posedge clk) begin
		if (current_state == s_ID)
			RR2 <= RF_rdata2;
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
	assign RF_wen = (current_state == s_WB && (!Rtype || Rtype && (func != FC_jr && func[5:1] != 5'b00101 || func[5:1] == 5'b00101 && (|RR2) == func[0])));	/* not Rtype; Rtype except [jr], [movz] and [movn]; [movz], [movn] */

	/* Control unit */
	assign NOP = (IR == 32'd0);
	assign Rtype = (opcode == 6'b000000 && NOP == 0);
	assign REGIMM = (opcode == 6'b000001);
	assign Jtype = (opcode[5:1] == 5'b00001);
	assign Itype_branch = (opcode[5:2] == 4'b0001);
	assign Itype_calc = (opcode[5:3] == 3'b001);
	assign Itype_r = (opcode[5:3] == 3'b100);
	assign Itype_w = (opcode[5:3] == 3'b101);
	assign RegDst = ~(Itype_calc || Itype_r || Itype_w);
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
	assign LoadB = Read_data[{ RF_wbuf[1:0],3'd0 } +: 8];
	assign LoadH = Read_data[{ RF_wbuf[1],4'd0 } +: 16];
	assign LoadWL = (
		{32{RF_wbuf[1:0] == 2'b00}} & { Read_data[7:0],RR2[23:0] } |
		{32{RF_wbuf[1:0] == 2'b01}} & { Read_data[15:0],RR2[15:0] } |
		{32{RF_wbuf[1:0] == 2'b10}} & { Read_data[23:0],RR2[7:0] } |
		{32{RF_wbuf[1:0] == 2'b11}} & Read_data
	);
	assign LoadWR = (
		{32{RF_wbuf[1:0] == 2'b00}} & Read_data |
		{32{RF_wbuf[1:0] == 2'b01}} & { RR2[31:24],Read_data[31:8] } |
		{32{RF_wbuf[1:0] == 2'b10}} & { RR2[31:16],Read_data[31:16] } |
		{32{RF_wbuf[1:0] == 2'b11}} & { RR2[31:8],Read_data[31:24] }
	);

	/* ALU */
	assign ALU_A_ex = (Rtype && (func == FC_jr || func == FC_jalr) || REGIMM || Itype_branch || Jtype ? PC : RR1);
	assign ALU_B_ex = (RF2ALU_B ? RR2 : (	/* Rtype::calc */
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
	assign SFT_B = {5{Rtype && func[5:2] == 4'b0000}} & IR[10:6] | {5{Rtype && func[5:2] == 4'b0001}} & RR1[4:0];
	assign SFTop = func[1:0];

	/* RAM */
	assign MemRead = (current_state == s_LD);
	assign MemWrite = (current_state == s_ST);
	assign Inst_Req_Valid = (current_state == s_IF);
	assign Inst_Ready = (current_state == s_IW || current_state == s_INIT);
	assign Read_data_Ready = (current_state == s_RDW || current_state == s_INIT);
	assign Address = { RF_wbuf[31:2],2'b0 };
	assign Write_data = {
		{32{opcode[1] == 0}} & (RR2 << { RF_wbuf[1:0],3'd0 }) |
		/* [sb], [sh] */
		{32{opcode[1:0] == 2'b11}} & RR2 |
		/* [sw] */
		{32{opcode[1:0] == 2'b10}} & (opcode[2] ? StoreWR : StoreWL)
		/* [swr], [swl] */
	};
	assign StoreWL = (
		{32{RF_wbuf[1:0] == 2'b00}} & { 24'd0,RR2[31:24] } |
		{32{RF_wbuf[1:0] == 2'b01}} & { 16'd0,RR2[31:16] } |
		{32{RF_wbuf[1:0] == 2'b10}} & { 8'd0,RR2[31:8] } |
		{32{RF_wbuf[1:0] == 2'b11}} & RR2
	);
	assign StoreWR = (
		{32{RF_wbuf[1:0] == 2'b00}} & RR2 |
		{32{RF_wbuf[1:0] == 2'b01}} & { RR2[23:0],8'd0 } |
		{32{RF_wbuf[1:0] == 2'b10}} & { RR2[15:0],16'd0 } |
		{32{RF_wbuf[1:0] == 2'b11}} & { RR2[7:0],24'd0 }
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
