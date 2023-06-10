`timescale 10ns / 1ns

`define CACHE_SET	8
`define CACHE_WAY	4
`define LOG_2WAY	2	/* Width of order of every way */
`define TAG_LEN		24
`define LINE_LEN	256
`define ADDR_WIDTH	3

module dcache_top (
	input	      clk,
	input	      rst,

	//CPU interface
	/** CPU memory/IO access request to Cache: valid signal */
	input         from_cpu_mem_req_valid,
	/** CPU memory/IO access request to Cache: 0 for read; 1 for write (when req_valid is high) */
	input         from_cpu_mem_req,
	/** CPU memory/IO access request to Cache: address (4 byte alignment) */
	input  [31:0] from_cpu_mem_req_addr,
	/** CPU memory/IO access request to Cache: 32-bit write data */
	input  [31:0] from_cpu_mem_req_wdata,
	/** CPU memory/IO access request to Cache: 4-bit write strobe */
	input  [ 3:0] from_cpu_mem_req_wstrb,
	/** Acknowledgement from Cache: ready to receive CPU memory access request */
	output        to_cpu_mem_req_ready,

	/** Cache responses to CPU: valid signal */
	output        to_cpu_cache_rsp_valid,
	/** Cache responses to CPU: 32-bit read data */
	output [31:0] to_cpu_cache_rsp_data,
	/** Acknowledgement from CPU: Ready to receive read data */
	input         from_cpu_cache_rsp_ready,
		
	//Memory/IO read interface
	/** Cache sending memory/IO read request: valid signal */
	output        to_mem_rd_req_valid,
	/** Cache sending memory read request: address
	  * 4 byte alignment for I/O read 
	  * 32 byte alignment for cache read miss */
	output [31:0] to_mem_rd_req_addr,
        /** Cache sending memory read request: burst length
	  * 0 for I/O read (read only one data beat)
	  * 7 for cache read miss (read eight data beats) */
	output [ 7:0] to_mem_rd_req_len,
        /** Acknowledgement from memory: ready to receive memory read request */
	input	      from_mem_rd_req_ready,

	/** Memory return read data: valid signal of one data beat */
	input	      from_mem_rd_rsp_valid,
	/** Memory return read data: 32-bit one data beat */
	input  [31:0] from_mem_rd_rsp_data,
	/** Memory return read data: if current data beat is the last in this burst data transmission */
	input	      from_mem_rd_rsp_last,
	/** Acknowledgement from cache: ready to receive current data beat */
	output        to_mem_rd_rsp_ready,

	//Memory/IO write interface
	/** Cache sending memory/IO write request: valid signal */
	output        to_mem_wr_req_valid,
	/** Cache sending memory write request: address
	  * 4 byte alignment for I/O write 
	  * 4 byte alignment for cache write miss
          * 32 byte alignment for cache write-back */
	output [31:0] to_mem_wr_req_addr,
        /** Cache sending memory write request: burst length
          * 0 for I/O write (write only one data beat)
          * 0 for cache write miss (write only one data beat)
          * 7 for cache write-back (write eight data beats) */
	output [ 7:0] to_mem_wr_req_len,
        /** Acknowledgement from memory: ready to receive memory write request */
	input         from_mem_wr_req_ready,

	/** Cache sending memory/IO write data: valid signal for current data beat */
	output        to_mem_wr_data_valid,
	/** Cache sending memory/IO write data: current data beat */
	output [31:0] to_mem_wr_data,
	/** Cache sending memory/IO write data: write strobe
	  * 4'b1111 for cache write-back 
	  * other values for I/O write and cache write miss according to the original CPU request*/ 
	output [ 3:0] to_mem_wr_data_strb,
	/** Cache sending memory/IO write data: if current data beat is the last in this burst data transmission */
	output        to_mem_wr_data_last,
	/** Acknowledgement from memory/IO: ready to receive current data beat */
	input	      from_mem_wr_data_ready
);

  //TODO: Please add your D-Cache code here

	/* States for FSM */
	localparam s_WAIT = 7'h1, s_LOAD = 7'h2, s_RECV = 7'h4,
		s_FILL = 7'h8, s_DONE = 7'h10, s_STOR = 7'h20, s_SEND = 7'h40;

	/* Memory request from CPU */
	localparam r_READ = 1'd0, r_WRITE = 1'd1;

	/* Valid array and Modified(Dirty) array */
	reg [`CACHE_SET * `CACHE_WAY - 1:0] Valid, Modified;
	/* usage: Valid[{ Addr,2'd0 } +: 4] */

	/* Access order array of every group:
	 for every group, the range is 2'd0~2'd3,
	 the way whose order is 3 will be replaced. */
	reg [`CACHE_SET * `CACHE_WAY * `LOG_2WAY - 1:0] Order;

	/* CPU write data, after Write_strb */
	wire [31:0] Write_data;

	/* Regs to save info from CPU */
	reg [31:0] CMAR;	/* CPU address reg */
	reg CMRR;	/* CPU memory request reg */
	reg [31:0] CMDR;	/* CPU memory data reg */
	reg [3:0] CWSR;	/* CPU Write_strb reg */

	/* Whether the address can use Cache */
	wire Flag_Bypass;

	wire [`CACHE_WAY * `LOG_2WAY - 1:0] Order_at_addr,
		Order_Offset, Order_sum_temp;
	wire [`CACHE_WAY - 1:0] Valid_at_addr, Modified_at_addr;

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
	/* Tag of the block to be refilled */
	wire [`TAG_LEN - 1:0] Tag_Target;

	/* Data to write to all ways */
	wire [`LINE_LEN - 1:0] Data_w;
	wire [`TAG_LEN - 1:0] Tag_w;

	/* Valid data reg */
	reg [31:0] VDR;

	/* The block HIT or to be REFILLED, it has 8 words */
	wire [`LINE_LEN - 1:0] Block_Target;

	/* Buffer for burst reading and writing memory */
	reg [`LINE_LEN - 1:0] Buffer;

	/* Send counter */
	reg [7:0] Send_ymr;

	/* Hit flag for every way at certain address */
	wire [`CACHE_WAY - 1:0] Flag_Hit;
	/* Miss flag, used to decide which way will be refilled */
	wire [`CACHE_WAY - 1:0] Flag_Miss;
	/* Target flag, used to point which way is hit or to be refilled */
	wire [`CACHE_WAY - 1:0] Flag_Target;
	/* reg of Flag_Target, used for refilling */
	reg [`CACHE_WAY - 1:0] FTR;
	/* reg of Tag_Target, used for writting back */
	reg [`TAG_LEN - 1:0] TTR;

	/* Order of target block, hit or to be refilled */
	wire [`LOG_2WAY - 1:0] Order_of_Target;

	/* Mask signals */
	wire [`LINE_LEN - 1:0] Mask32_for_Data,	/* 32 "1"s */
		Shifted_Write_data;
	wire [`CACHE_SET * `CACHE_WAY * `LOG_2WAY - 1:0]
		Mask8_for_Order;	/* 8 "1"s */

	/* 32 bits Write_strb */
	wire [31:0] Wstrb32;

	/* For FSM */
	reg [6:0] current_state, next_state;
	wire Flag_WAIT;
	/* Virtual init state */
	reg IFR;

	assign Flag_WAIT = (current_state == s_WAIT);

	assign Valid_at_addr = Valid[{ Array_addr,`LOG_2WAY'd0 } +: `CACHE_WAY],
		Modified_at_addr = Modified[{ Array_addr,`LOG_2WAY'd0 } +: `CACHE_WAY],
		Order_at_addr = Order[{ Array_addr,3'd0 } +: (`CACHE_WAY * `LOG_2WAY)];
		/* Array_addr * `CACHE_WAY * `LOG_2WAY */
	
	assign { Addr_Tag,Addr_Index,Addr_Offset } = (
		Flag_WAIT ? from_cpu_mem_req_addr : CMAR
	);

	assign Array_addr = Addr_Index;

	assign Flag_Hit = Valid_at_addr & {
		Addr_Tag == Tag_r[(3 * `TAG_LEN) +: `TAG_LEN],
		Addr_Tag == Tag_r[(2 * `TAG_LEN) +: `TAG_LEN],
		Addr_Tag == Tag_r[(1 * `TAG_LEN) +: `TAG_LEN],
		Addr_Tag == Tag_r[(0 * `TAG_LEN) +: `TAG_LEN]
	};

	/* Just find the first way whose order is 3 */
	assign Flag_Miss[0] = &Order_at_addr[(0 * `LOG_2WAY) +: `LOG_2WAY],
		Flag_Miss[1] = (
			!Flag_Miss[0] &&
			&Order_at_addr[(1 * `LOG_2WAY) +: `LOG_2WAY]
		),
		Flag_Miss[2] = (
			!Flag_Miss[0] && !Flag_Miss[1] &&
			&Order_at_addr[(2 * `LOG_2WAY) +: `LOG_2WAY]
		),
		Flag_Miss[3] = (
			!Flag_Miss[0] && !Flag_Miss[1] && !Flag_Miss[2] &&
			&Order_at_addr[(3 * `LOG_2WAY) +: `LOG_2WAY]
		);

	assign Block_Target = (
		{`LINE_LEN{Flag_Target[3]}} & Data_r[(3 * `LINE_LEN) +: `LINE_LEN] |
		{`LINE_LEN{Flag_Target[2]}} & Data_r[(2 * `LINE_LEN) +: `LINE_LEN] |
		{`LINE_LEN{Flag_Target[1]}} & Data_r[(1 * `LINE_LEN) +: `LINE_LEN] |
		{`LINE_LEN{Flag_Target[0]}} & Data_r[(0 * `LINE_LEN) +: `LINE_LEN]
	);

	assign Tag_Target = (
		{`TAG_LEN{Flag_Miss[3]}} & Tag_r[(3 * `TAG_LEN) +: `TAG_LEN] |
		{`TAG_LEN{Flag_Miss[2]}} & Tag_r[(2 * `TAG_LEN) +: `TAG_LEN] |
		{`TAG_LEN{Flag_Miss[1]}} & Tag_r[(1 * `TAG_LEN) +: `TAG_LEN] |
		{`TAG_LEN{Flag_Miss[0]}} & Tag_r[(0 * `TAG_LEN) +: `TAG_LEN]
	);

	/* Flag_Target is Flag_Hit when cache hit, or Flag_Miss otherwise */
	assign Flag_Target = (
		{`CACHE_WAY{|Flag_Hit}} & Flag_Hit |
		{`CACHE_WAY{~(|Flag_Hit)}} & Flag_Miss
	);

	assign Flag_Bypass = (
		(Addr_Tag[(`TAG_LEN - 1) -: 2] != 2'd0) ||	/* >= 0x4000_0000 */
		(Addr_Tag == `TAG_LEN'd0) && (Addr_Index == `ADDR_WIDTH'd0)	/* <= 0x0000_001F */
	);

	assign Order_of_Target = (
		{`LOG_2WAY{Flag_Target[3]}} & Order_at_addr[(3 * `LOG_2WAY) +: `LOG_2WAY] |
		{`LOG_2WAY{Flag_Target[2]}} & Order_at_addr[(2 * `LOG_2WAY) +: `LOG_2WAY] |
		{`LOG_2WAY{Flag_Target[1]}} & Order_at_addr[(1 * `LOG_2WAY) +: `LOG_2WAY] |
		{`LOG_2WAY{Flag_Target[0]}} & Order_at_addr[(0 * `LOG_2WAY) +: `LOG_2WAY]
	);

	/* To modify order of 4 ways at certain address */
	assign Order_Offset = {
		{`LOG_2WAY{Flag_Target[3]}} & (-Order_of_Target) |
		{`LOG_2WAY{Order_at_addr[(3 * `LOG_2WAY) +: `LOG_2WAY] < Order_of_Target}} & `LOG_2WAY'd1,
		{`LOG_2WAY{Flag_Target[2]}} & (-Order_of_Target) |
		{`LOG_2WAY{Order_at_addr[(2 * `LOG_2WAY) +: `LOG_2WAY] < Order_of_Target}} & `LOG_2WAY'd1,
		{`LOG_2WAY{Flag_Target[1]}} & (-Order_of_Target) |
		{`LOG_2WAY{Order_at_addr[(1 * `LOG_2WAY) +: `LOG_2WAY] < Order_of_Target}} & `LOG_2WAY'd1,
		{`LOG_2WAY{Flag_Target[0]}} & (-Order_of_Target) |
		{`LOG_2WAY{Order_at_addr[(0 * `LOG_2WAY) +: `LOG_2WAY] < Order_of_Target}} & `LOG_2WAY'd1
	};

	data_array Darray[`CACHE_WAY - 1:0] (
		/* Only wen and rdata are separate for 4 ways */
		.clk(clk), .waddr(Array_addr), .raddr(Array_addr),
		.wen(Array_wen), .wdata(Data_w), .rdata(Data_r)
	);
	/* Only wdata and rdata are separate for Darray and Tarray */
	tag_array Tarray[`CACHE_WAY - 1:0] (
		/* Only wen and rdata are separate for 4 ways */
		.clk(clk), .waddr(Array_addr), .raddr(Array_addr),
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
		s_WAIT:
			if (IFR || !from_cpu_mem_req_valid)
				next_state = s_WAIT;
			else if (Flag_Bypass) begin
				if (from_cpu_mem_req == r_READ)
					next_state = s_LOAD;
				else
					next_state = s_STOR;
			end
			else begin
				if (Flag_Hit != `CACHE_WAY'd0)
					/* Hit */
					next_state = s_DONE;
				else begin
					/* Miss */
					if ((Modified_at_addr & Flag_Miss) == `CACHE_WAY'd0)
						/* NOT modified */
						next_state = s_LOAD;
					else	/* Modified */
						next_state = s_STOR;
				end
			end
		s_LOAD:
			if (from_mem_rd_req_ready)
				next_state = s_RECV;
			else
				next_state = s_LOAD;
		s_RECV:
			if (!from_mem_rd_rsp_valid)
				next_state = s_RECV;
			else if (Flag_Bypass)
				next_state = s_DONE;
			else if (from_mem_rd_rsp_last)
				/* Can use Cache */
				next_state = s_FILL;
			else
				next_state = s_RECV;
		s_FILL:
			next_state = s_DONE;
		s_DONE:
			if (from_cpu_cache_rsp_ready || CMRR == r_WRITE)
				next_state = s_WAIT;
			else
				next_state = s_DONE;
		s_STOR:
			if (from_mem_wr_req_ready)
				next_state = s_SEND;
			else
				next_state = s_STOR;
		default:	/* s_SEND */
			if (!from_mem_wr_data_ready)
				next_state = s_SEND;
			else if (Flag_Bypass)
				next_state = s_DONE;
			else begin	/* Can use Cache */
				if (to_mem_wr_data_last)
					next_state = s_LOAD;
				else
					next_state = s_SEND;
			end
		endcase
	end

	/* VDR */
	always @ (posedge clk) begin
		if (next_state == s_DONE) begin
			if (Flag_WAIT && from_cpu_mem_req == r_READ)
				/* Read hit */
				VDR <= Block_Target[{ Addr_Offset[4:2],5'd0 } +: 32];
			else if (current_state == s_FILL && CMRR == r_READ)
				/* Read miss: Write_data is exactly the data needed! */
				VDR <= Write_data;
			else if (current_state == s_RECV && Flag_Bypass && from_mem_rd_rsp_valid)
				/* Read through bypass */
				VDR <= from_mem_rd_rsp_data;
		end
	end

	/* Valid */
	always @ (posedge clk) begin
		if (rst)
			Valid <= {(`CACHE_SET * `CACHE_WAY){1'd0}};
		else if (current_state == s_FILL)
			Valid <= Valid | (
				{ {((`CACHE_SET - 1) * `CACHE_WAY){1'd0}},FTR }
					<< { Array_addr,`LOG_2WAY'd0 }
			);
	end

	assign Order_sum_temp[(3 * `LOG_2WAY) +: `LOG_2WAY] =
		Order_at_addr[(3 * `LOG_2WAY) +: `LOG_2WAY] + Order_Offset[(3 * `LOG_2WAY) +: `LOG_2WAY],
		Order_sum_temp[(2 * `LOG_2WAY) +: `LOG_2WAY] =
		Order_at_addr[(2 * `LOG_2WAY) +: `LOG_2WAY] + Order_Offset[(2 * `LOG_2WAY) +: `LOG_2WAY],
		Order_sum_temp[(1 * `LOG_2WAY) +: `LOG_2WAY] =
		Order_at_addr[(1 * `LOG_2WAY) +: `LOG_2WAY] + Order_Offset[(1 * `LOG_2WAY) +: `LOG_2WAY],
		Order_sum_temp[(0 * `LOG_2WAY) +: `LOG_2WAY] =
		Order_at_addr[(0 * `LOG_2WAY) +: `LOG_2WAY] + Order_Offset[(0 * `LOG_2WAY) +: `LOG_2WAY];

	assign Mask8_for_Order = (
		{ {((`CACHE_SET - 1) * `CACHE_WAY * `LOG_2WAY){1'd0}},{(`CACHE_WAY * `LOG_2WAY){1'd1}} }
			<< { Array_addr,3'd0 }	/* Array_addr * `CACHE_WAY * `LOG_2WAY */
	);	/* 8 "1"s in 64 bits */

	/* Order */
	always @ (posedge clk) begin
		if (rst)
			Order <= {(`CACHE_SET * `CACHE_WAY * `LOG_2WAY){1'd1}};
		else if (Flag_WAIT && next_state != s_WAIT && !Flag_Bypass)
			/* Renew order */
			Order <= Order & ~Mask8_for_Order | (
				{ {((`CACHE_SET - 1) * `CACHE_WAY * `LOG_2WAY){1'd0}},Order_sum_temp }
					<< { Array_addr,3'd0 }	/* Array_addr * `CACHE_WAY * `LOG_2WAY */
			);
	end

	/* Modified */
	always @ (posedge clk) begin
		if (rst)
			Modified <= {(`CACHE_SET * `CACHE_WAY){1'd0}};
		else if (Flag_WAIT && next_state == s_DONE &&
			from_cpu_mem_req == r_WRITE)
			/* Write hit */
			Modified <= Modified | (
				{ {((`CACHE_SET - 1) * `CACHE_WAY){1'd0}},Flag_Hit }
					<< { Array_addr,`LOG_2WAY'd0 }
			);
		else if (current_state == s_FILL && CMRR == r_WRITE)
			/* Write miss */
			Modified <= Modified | (
				{ {((`CACHE_SET - 1) * `CACHE_WAY){1'd0}},FTR }
					<< { Array_addr,`LOG_2WAY'd0 }
			);
		else if (current_state == s_FILL && CMRR == r_READ)
			/* Read miss, refill */
			Modified <= Modified & ~(
				{ {((`CACHE_SET - 1) * `CACHE_WAY){1'd0}},FTR }
					<< { Array_addr,`LOG_2WAY'd0 }
			);
	end

	assign Mask32_for_Data = (
		{ {(`LINE_LEN - 32){1'd0}},~32'd0 } << { Addr_Offset[4:2],5'd0 }
	),	/* 32 "1"s in 256 bits */
		Shifted_Write_data = (
		{ {(`LINE_LEN - 32){1'd0}},Write_data } << { Addr_Offset[4:2],5'd0 }
	);

	/* Connect to Tarray and Darray */
	assign Array_wen = (
		{`CACHE_WAY{Flag_WAIT && next_state == s_DONE &&
			from_cpu_mem_req == r_WRITE}} & Flag_Hit |
		{`CACHE_WAY{current_state == s_FILL}} & FTR
	);
	assign Tag_w = Addr_Tag,
		Data_w = (
			{`LINE_LEN{Flag_WAIT}} & 
			(Block_Target & ~Mask32_for_Data | Shifted_Write_data) |
			/* Write hit */
			{`LINE_LEN{current_state == s_FILL}} &
			(Buffer & ~Mask32_for_Data | Shifted_Write_data)
			/* Refill */
		);
	/* NOTE: If this is not a write request, CWSR will be 4'd0.
	 So, Data_w will be the same as Buffer. 
	 Besides, Write_data will be the data need to be read. */
	assign Wstrb32 = {
		{8{Flag_WAIT & from_cpu_mem_req_wstrb[3] | ~Flag_WAIT & CWSR[3]}},
		{8{Flag_WAIT & from_cpu_mem_req_wstrb[2] | ~Flag_WAIT & CWSR[2]}},
		{8{Flag_WAIT & from_cpu_mem_req_wstrb[1] | ~Flag_WAIT & CWSR[1]}},
		{8{Flag_WAIT & from_cpu_mem_req_wstrb[0] | ~Flag_WAIT & CWSR[0]}}
	};

	assign Write_data = (
		Wstrb32 & ({32{Flag_WAIT}} & from_cpu_mem_req_wdata | {32{~Flag_WAIT}} & CMDR) |
		~Wstrb32 & ({32{Flag_WAIT}} & Block_Target[{ Addr_Offset[4:2],5'd0 } +: 32] |
		{32{~Flag_WAIT}} & Buffer[{ Addr_Offset[4:2],5'd0 } +: 32])
	);
	
	/* Buffer */
	always @ (posedge clk) begin
		if (current_state == s_LOAD && next_state == s_RECV)
			/* Clear before use, although unnecessary */
			Buffer <= `LINE_LEN'd0;
		else if (current_state == s_RECV && from_mem_rd_rsp_valid && !Flag_Bypass)
			/* Receiving data from main memory(Burst) */
			Buffer <= { from_mem_rd_rsp_data,Buffer[`LINE_LEN - 1:32] };
		else if (Flag_WAIT && next_state == s_STOR && !Flag_Bypass)
			/* Miss and the target has been modified,
			 prepare to write back. */
			Buffer <= Block_Target;
	end

	/* Send_ymr */
	always @ (posedge clk) begin
		if (Flag_WAIT && next_state == s_STOR)
			Send_ymr <= 8'd0;	/* Clear */
		else if ((/*current_state == s_STOR || */current_state == s_SEND)
			&& from_mem_wr_data_ready)
			/* Set counter */
			Send_ymr <= Send_ymr + 8'd1;
	end

	/* Connect to CPU */
	assign to_cpu_mem_req_ready = Flag_WAIT,
		to_cpu_cache_rsp_valid = (CMRR == r_READ && current_state == s_DONE),
		to_cpu_cache_rsp_data = ({32{CMRR == r_READ}} & VDR);

	/* Connect to Main memory */
	assign to_mem_rd_req_valid = (current_state == s_LOAD),
		to_mem_rd_req_addr = {
			Addr_Tag,Addr_Index,
			{{(32 - `TAG_LEN - `ADDR_WIDTH){Flag_Bypass}} &
				{ Addr_Offset[(31 - `TAG_LEN - `ADDR_WIDTH):2],2'd0 }}
			/* Bypass: 4 B aligned; Burst: 32 B aligned */
		},
		to_mem_rd_req_len = {8{~Flag_Bypass}} & 8'd7,
		to_mem_rd_rsp_ready = (IFR || current_state == s_RECV);
	assign to_mem_wr_req_valid = (current_state == s_STOR),
		to_mem_wr_req_addr = (
			{32{Flag_Bypass}} & CMAR |
			/* Bypass: CMAR is already 4 B aligned */
			{32{~Flag_Bypass}} &
			{ TTR,Addr_Index,{(32 - `TAG_LEN - `ADDR_WIDTH){1'd0}} }
			/* Burst: 32 B aligned */
		),
		to_mem_wr_req_len = to_mem_rd_req_len;
	assign to_mem_wr_data_valid = (
		/*current_state == s_STOR || */current_state == s_SEND
	),
		to_mem_wr_data = (
			{32{Flag_Bypass}} & CMDR |
			/* Bypass */
			{32{~Flag_Bypass}} & Buffer[{ Send_ymr,5'd0 } +: 32]
			/* Burst */
		),
		to_mem_wr_data_strb = (
			{4{Flag_Bypass}} & CWSR | {4{~Flag_Bypass}}
			/* Bypass and burst */
		),
		to_mem_wr_data_last = (
			current_state == s_SEND && Send_ymr == to_mem_wr_req_len
		);

	/* IFR */
	always @ (posedge clk) begin
		IFR <= rst;
		/* To yield a virtual initial state */
	end

	/* CMAR */
	always @ (posedge clk) begin
		if (Flag_WAIT && next_state != s_WAIT)
			CMAR <= { from_cpu_mem_req_addr[31:2],2'd0 };
	end

	/* CMRR */
	always @ (posedge clk) begin
		if (Flag_WAIT && next_state != s_WAIT)
			CMRR <= from_cpu_mem_req;
	end

	/* CMDR */
	always @ (posedge clk) begin
		if (Flag_WAIT && next_state != s_WAIT)
			CMDR <= from_cpu_mem_req_wdata;
	end

	/* CWSR */
	always @ (posedge clk) begin
		if (Flag_WAIT && next_state != s_WAIT)
			CWSR <= {4{from_cpu_mem_req == r_WRITE}} & from_cpu_mem_req_wstrb;
	end

	/* FTR */
	always @ (posedge clk) begin
		if (Flag_WAIT && next_state != s_WAIT)
			/* Miss */
			FTR <= Flag_Target;
	end

	/* TTR */
	always @ (posedge clk) begin
		if (Flag_WAIT && next_state == s_STOR)
			TTR <= Tag_Target;
		/* When miss and the block to be refilled has been modified,
		 get its tag for writting back. */
	end

endmodule
