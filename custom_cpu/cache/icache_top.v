`timescale 10ns / 1ns

`define CACHE_SET	8
`define CACHE_WAY	4
`define LOG_2WAY	2	/* Width of order of every way */
`define TAG_LEN		24
`define LINE_LEN	256
`define ADDR_WIDTH	3

module icache_top (
	input	      clk,
	input	      rst,
	
	//CPU interface
	/** CPU instruction fetch request to Cache: valid signal */
	input         from_cpu_inst_req_valid,
	/** CPU instruction fetch request to Cache: address (4 byte alignment) */
	input  [31:0] from_cpu_inst_req_addr,
	/** Acknowledgement from Cache: ready to receive CPU instruction fetch request */
	output        to_cpu_inst_req_ready,
	
	/** Cache responses to CPU: valid signal */
	output        to_cpu_cache_rsp_valid,
	/** Cache responses to CPU: 32-bit Instruction value */
	output [31:0] to_cpu_cache_rsp_data,
	/** Acknowledgement from CPU: Ready to receive Instruction */
	input	      from_cpu_cache_rsp_ready,

	//Memory interface (32 byte aligned address)
	/** Cache sending memory read request: valid signal */
	output        to_mem_rd_req_valid,
	/** Cache sending memory read request: address (32 byte alignment) */
	output [31:0] to_mem_rd_req_addr,
	/** Acknowledgement from memory: ready to receive memory read request */
	input         from_mem_rd_req_ready,

	/** Memory return read data: valid signal of one data beat */
	input         from_mem_rd_rsp_valid,
	/** Memory return read data: 32-bit one data beat */
	input  [31:0] from_mem_rd_rsp_data,
	/** Memory return read data: if current data beat is the last in this burst data transmission */
	input         from_mem_rd_rsp_last,
	/** Acknowledgement from cache: ready to receive current data beat */
	output        to_mem_rd_rsp_ready
);

//TODO: Please add your I-Cache code here

	localparam s_WAIT = 5'h1, s_LOAD = 5'h2,
		s_RECV = 5'h4, s_FILL = 5'h8, s_DONE = 5'h10;

	/* Valid array */
	reg [`CACHE_SET * `CACHE_WAY - 1:0] Valid;
	/* usage: Valid[{ Addr,2'd0 } +: 4] */

	/* Access order array of every group:
	 for every group, the range is 2'd0~2'd3,
	 the way whose order is 3 will be replaced. */
	reg [`CACHE_SET * `CACHE_WAY * `LOG_2WAY - 1:0] Order;

	reg [31:0] CAR;	/* CPU address reg */

	wire [`CACHE_WAY * `LOG_2WAY - 1:0] Order_at_raddr,
		Order_at_waddr, Order_Offset;
	wire [`CACHE_WAY - 1:0] Valid_at_raddr, Valid_at_waddr;

	wire [`TAG_LEN - 1:0] Addr_Tag;
	wire [`ADDR_WIDTH - 1:0] Addr_Index;
	wire [31 - `TAG_LEN - `ADDR_WIDTH:0] Addr_Offset;	/* 5 bits */

	/* Write-enable signal of every way */
	wire [`CACHE_WAY - 1:0] Array_wen;
	/* Address of all ways */
	wire [`ADDR_WIDTH - 1:0] Array_addr;

	/* Data read from every way:
	 255~0 for way 0, ..., 1023~768 for way 3. */
	wire [`CACHE_WAY * `LINE_LEN - 1:0] Data_r;
	/* Tag read from every way:
	 23~0 for way 0, ..., 95~72 for way 3. */
	wire [`CACHE_WAY * `TAG_LEN - 1:0] Tag_r;

	/* Data to write to all ways */
	wire [`LINE_LEN - 1:0] Data_w;
	wire [`TAG_LEN - 1:0] Tag_w;

	/* Valid data reg */
	reg [31:0] VDR;

	/* The HIT block of cache, it has 8 words */
	wire [`LINE_LEN - 1:0] Block_Hit;

	/* Hit flag for every way at certain address */
	wire [`CACHE_WAY - 1:0] Flag_Hit;
	/* Miss flag, used to decide which way will be refilled */
	wire [`CACHE_WAY - 1:0] Flag_Miss;
	/* Target flag, used to point which way is hit or to be refilled */
	wire [`CACHE_WAY - 1:0] Flag_Target;

	/* Order of target block, hit or to be refilled */
	wire [`LOG_2WAY - 1:0] Order_of_Target;

	/* For FSM */
	reg [4:0] current_state, next_state;

	/* Virtual init state */
	reg IFR;

	assign Valid_at_raddr = Order[{ Array_addr,`LOG_2WAY'd0 } +: `CACHE_WAY],
		Order_at_raddr = Order[{ Array_addr,3'd0 } +: (`CACHE_WAY * `LOG_2WAY) ];
		/* Array_addr * `CACHE_WAY * `LOG_2WAY */
	
	assign { Addr_Tag,Addr_Index,Addr_Offset } = (
		current_state == s_WAIT ? from_cpu_inst_req_addr : CAR
	);

	assign Array_addr = Addr_Index;

	assign Flag_Hit = Valid_at_raddr & {
		Addr_Tag == Tag_r[(3 * `TAG_LEN) +: `TAG_LEN],
		Addr_Tag == Tag_r[(2 * `TAG_LEN) +: `TAG_LEN],
		Addr_Tag == Tag_r[(1 * `TAG_LEN) +: `TAG_LEN],
		Addr_Tag == Tag_r[(0 * `TAG_LEN) +: `TAG_LEN]
	};

	/* Just find the first way whose order is 3 */
	assign Flag_Miss[0] = &Order_at_raddr[(0 * `LOG_2WAY) +: `LOG_2WAY],
		Flag_Miss[1] = (
			!Flag_Miss[0] &&
			&Order_at_raddr[(1 * `LOG_2WAY) +: `LOG_2WAY]
		),
		Flag_Miss[2] = (
			!Flag_Miss[0] && !Flag_Miss[1] &&
			&Order_at_raddr[(2 * `LOG_2WAY) +: `LOG_2WAY]
		),
		Flag_Miss[3] = (
			!Flag_Miss[0] && !Flag_Miss[1] && Flag_Miss[2] &&
			&Order_at_raddr[(3 * `LOG_2WAY) +: `LOG_2WAY]
		);

	assign Block_Hit = (
		{`LINE_LEN{Flag_Hit[3]}} & Data_r[(3 * `LINE_LEN) +: `LINE_LEN] |
		{`LINE_LEN{Flag_Hit[2]}} & Data_r[(2 * `LINE_LEN) +: `LINE_LEN] |
		{`LINE_LEN{Flag_Hit[1]}} & Data_r[(1 * `LINE_LEN) +: `LINE_LEN] |
		{`LINE_LEN{Flag_Hit[0]}} & Data_r[(0 * `LINE_LEN) +: `LINE_LEN]
	);

	/* Flag_Target is Flag_Hit when cache hit, or Flag_Miss otherwise */
	assign Flag_Target = (
		(Flag_Hit == `CACHE_WAY'd0) ? Flag_Miss : Flag_Hit
	);

	assign Order_of_Target = (
		{`LOG_2WAY{Flag_Target[3]}} & Order_at_raddr[(3 * `LOG_2WAY) + `LOG_2WAY] |
		{`LOG_2WAY{Flag_Target[2]}} & Order_at_raddr[(2 * `LOG_2WAY) + `LOG_2WAY] |
		{`LOG_2WAY{Flag_Target[1]}} & Order_at_raddr[(1 * `LOG_2WAY) + `LOG_2WAY] |
		{`LOG_2WAY{Flag_Target[0]}} & Order_at_raddr[(0 * `LOG_2WAY) + `LOG_2WAY]
	);

	/* To modify order of 4 ways at certain address */
	assign Order_Offset = {
		{`LOG_2WAY{Flag_Target[3]}} & (-Order_of_Target) |
		{`LOG_2WAY{Order_at_raddr[(3 * `LOG_2WAY) + `LOG_2WAY] < Order_of_Target}} & `LOG_2WAY'd1,
		{`LOG_2WAY{Flag_Target[2]}} & (-Order_of_Target) |
		{`LOG_2WAY{Order_at_raddr[(2 * `LOG_2WAY) + `LOG_2WAY] < Order_of_Target}} & `LOG_2WAY'd1,
		{`LOG_2WAY{Flag_Target[1]}} & (-Order_of_Target) |
		{`LOG_2WAY{Order_at_raddr[(1 * `LOG_2WAY) + `LOG_2WAY] < Order_of_Target}} & `LOG_2WAY'd1,
		{`LOG_2WAY{Flag_Target[0]}} & (-Order_of_Target) |
		{`LOG_2WAY{Order_at_raddr[(0 * `LOG_2WAY) + `LOG_2WAY] < Order_of_Target}} & `LOG_2WAY'd1
	};

	data_array Darray[`CACHE_WAY - 1:0] (
		/* Only wen and rdata are separate for 4 ways */
		.clk(clk), .waddr(Array_waddr), .raddr(Array_addr),
		.wen(Array_wen), .wdata(Data_w), .rdata(Data_r)
	);
	/* Only wdata and rdata are separate for Darray and Tarray */
	tag_array Tarray[`CACHE_WAY - 1:0] (
		/* Only wen and rdata are separate for 4 ways */
		.clk(clk), .waddr(Array_waddr), .raddr(Array_addr),
		.wen(Array_wen), .wdata(Tag_w), .rdata(Tag_r)
	);

	/* FSM 1 */
	always @ (posedge clk) begin
		if (rst)
			current_state <= s_WAIT;
		else
			current_state <= next_state;
	end

	/* FSM 2 */
	always @ (*) begin
		case (current_state)
		s_WAIT:	/* Waiting for CPU's request */
			if (IFR || !from_cpu_inst_req_valid)
				next_state = s_WAIT;
			else if (Flag_Hit == `CACHE_WAY'd0)
				/* Miss */
				next_state = s_LOAD;
			else	/* Hit */
				next_state = s_DONE;
		s_LOAD:	/* Prepare to read memory */
			if (from_mem_rd_req_ready)
				next_state = s_RECV;
			else
				next_state = s_LOAD;
		s_RECV:	/* Receive data from memory */
			if (from_mem_rd_rsp_valid && from_mem_rd_rsp_last)
				next_state = s_FILL;
			else
				next_state = s_RECV;
		s_FILL:	/* Refill cache */
			next_state = s_DONE;
		default:	/* s_DONE */
			/* Waiting for CPU's response */
			if (from_cpu_cache_rsp_ready)
				next_state = s_WAIT;
			else	/* Waiting for CPU */
				next_state = s_DONE;
		endcase
	end

	/* IFR */
	always @ (posedge clk) begin
		IFR <= rst;
		/* To yield a virtual initial state */
	end

	/* CAR */
	always @ (posedge clk) begin
		if (current_state == s_WAIT && next_state != s_WAIT)
			CAR <= from_cpu_inst_req_addr;
	end

	/* VDR */
	always @ (posedge clk) begin
		if (next_state == s_DONE) begin
			if (current_state == s_WAIT)
				/* After hitting */
				VDR <= Block_Hit[{ Addr_Offset[4:2],5'd0 } +: `LINE_LEN];
			else
				;// TODO: after refilling
		end
	end

	/* Order */
	always @ (posedge clk) begin
		if (rst)
			Order <= {(`CACHE_SET * `CACHE_WAY * `LOG_2WAY){1'd1}};
		else if (current_state == s_WAIT && next_state != s_WAIT)
			/* Renew order */
			Order <= Order + (
				{ {((`CACHE_SET - 1) * `CACHE_WAY * `LOG_2WAY){1'd0}},Order_Offset }
					<< { Array_addr,3'd0 }	/* Array_addr * `CACHE_WAY * `LOG_2WAY */
			);
	end

	/* Connect to CPU */
	assign to_cpu_inst_req_ready = (current_state == s_WAIT),
		to_cpu_cache_rsp_valid = (current_state == s_DONE),
		to_cpu_cache_rsp_data = VDR;
	
	/* Connect to main memory */
	assign to_mem_rd_req_valid = (current_state == s_LOAD),
		to_mem_rd_rsp_ready = (current_state == s_RECV),
		to_mem_rd_req_addr = { Addr_Tag,Addr_Index,{(31 - `TAG_LEN - `ADDR_WIDTH){1'd0}} };

endmodule

