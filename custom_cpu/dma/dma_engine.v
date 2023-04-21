//////////////////////////////////////////////////////////////////////////////////
//* Author: Xu Zhang (zhangxu415@mails.ucas.ac.cn)

// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`define C_M_AXI_ADDR_WIDTH 32

module dma_engine  #(
	parameter integer  C_M_AXI_DATA_WIDTH = 32,
	parameter integer  ADDR_WIDTH         = 12
)
(
	input                               M_AXI_ACLK,
	input                               M_AXI_ARESET,
	
	input  [ADDR_WIDTH        -3 :0]    reg_addr,
	input  [C_M_AXI_DATA_WIDTH-1 :0]    reg_wdata,
	input                               reg_write,
	output [C_M_AXI_DATA_WIDTH-1 :0]    reg_rdata,

	output                              intr,
	
	// Master Interface Write Address
	output [                   39:0]    M_AXI_AWADDR,
	output [                    7:0]    M_AXI_AWLEN,
	output [                    1:0]    M_AXI_AWBURST,
	output [                    2:0]    M_AXI_AWSIZE,
	output                              M_AXI_AWVALID,
	input                               M_AXI_AWREADY,
	
	// Master Interface Write Data
	output [C_M_AXI_DATA_WIDTH-1 :0]    M_AXI_WDATA,
	output                              M_AXI_WLAST,
	output [                    3:0]    M_AXI_WSTRB,
	output                              M_AXI_WVALID,
	input                               M_AXI_WREADY,
	
	// Master Interface Read Address
	output [                   39:0]    M_AXI_ARADDR,
	output [                    7:0]    M_AXI_ARLEN,
	output [                    1:0]    M_AXI_ARBURST,
	output [                    2:0]    M_AXI_ARSIZE,
	output                              M_AXI_ARVALID,
	input                               M_AXI_ARREADY,
	
	// Master Interface Read Data
	input  [C_M_AXI_DATA_WIDTH-1 :0]    M_AXI_RDATA,
	input                               M_AXI_RLAST,
	input                               M_AXI_RVALID,
	input  [                    1:0]    M_AXI_RRESP,
	output                              M_AXI_RREADY,

	//AXI B channel for I/O
	output                              M_AXI_BREADY,
	input  [                    1:0]    M_AXI_BRESP,
	input                               M_AXI_BVALID
);

    wire          fifo_rden;
    wire  [31:0]  fifo_wdata;
    wire          fifo_wen;
    
    wire  [31:0]  fifo_rdata;
    wire          fifo_is_empty;
    wire          fifo_is_full;
      
    wire  [31:0]  src_base;
    wire  [31:0]  dest_base;
    wire  [31:0]  tail_ptr;
    wire  [31:0]  head_ptr;
    wire  [31:0]  dma_size;
    wire  [31:0]  ctrl_stat;
    wire  [31:0]  reg_wr_data;
    wire  [ 5:0]  reg_wr_en;

    wire  [ 4:0]  rd_req_len;
    wire  [ 4:0]  wr_req_len;

    wire  [`C_M_AXI_ADDR_WIDTH-1:0]    dma_axi_awaddr;
    wire  [`C_M_AXI_ADDR_WIDTH-1:0]    dma_axi_araddr;

    wire  [ 3:0]  dma_axi_awlen;
    wire  [ 3:0]  dma_axi_arlen;
    
    assign  reg_rdata = (~reg_addr[2] & ~reg_addr[1] & ~reg_addr[0]) ? src_base : 
                         ((~reg_addr[2] & ~reg_addr[1] & reg_addr[0]) ? dest_base : 
                         ((~reg_addr[2] & reg_addr[1] & ~reg_addr[0]) ? tail_ptr :
                         ((~reg_addr[2] & reg_addr[1] & reg_addr[0]) ? head_ptr : 
                         ((reg_addr[2] & ~reg_addr[1] & ~reg_addr[0]) ? dma_size : 
                         ((reg_addr[2] & ~reg_addr[1] & reg_addr[0]) ? ctrl_stat : 'd0)
		         ))));
    
    assign  reg_wr_data = reg_wdata;
    
    assign  reg_wr_en = {(reg_write & reg_addr[2] & ~reg_addr[1] & reg_addr[0]), (reg_write & reg_addr[2] & ~reg_addr[1] & ~reg_addr[0]),
                         (reg_write & ~reg_addr[2] & reg_addr[1] & reg_addr[0]), (reg_write & ~reg_addr[2] & reg_addr[1] & ~reg_addr[0]),
                         (reg_write & ~reg_addr[2] & ~reg_addr[1] & reg_addr[0]), (reg_write & ~reg_addr[2] & ~reg_addr[1] & ~reg_addr[0])};

    assign  M_AXI_AWADDR  = {8'd0, dma_axi_awaddr};
    assign  M_AXI_AWBURST = 2'b01;
    assign  M_AXI_AWSIZE  = 'd2;
    assign  M_AXI_AWLEN   = {3'd0, dma_axi_awlen};
    
    assign  M_AXI_WSTRB   = 4'b1111;

    assign  M_AXI_BREADY  = 1'b1;
    
    assign  M_AXI_ARADDR  = {8'd0, dma_axi_araddr};
    assign  M_AXI_ARBURST = 2'b01;
    assign  M_AXI_ARSIZE  = 'd2;
    assign  M_AXI_ARLEN   = {3'd0, dma_axi_arlen};
		 
    engine_core  u_engine_core (
	    .clk                    (M_AXI_ACLK),
	    .rst                    (M_AXI_ARESET),
	    
	    .src_base               (src_base),
	    .dest_base              (dest_base),
	    .tail_ptr               (tail_ptr),
	    .head_ptr               (head_ptr),
	    .dma_size               (dma_size),
	    .ctrl_stat              (ctrl_stat),
	    .reg_wr_data            (reg_wr_data),
	    .reg_wr_en              (reg_wr_en),
	    
	    .intr                   (intr),
	    
	    .rd_req_addr            (dma_axi_araddr),
	    .rd_req_len             (dma_axi_arlen),
	    .rd_req_valid           (M_AXI_ARVALID),
	    .rd_req_ready           (M_AXI_ARREADY),
	    .rd_rdata               (M_AXI_RDATA),
	    .rd_last                (M_AXI_RLAST),
	    .rd_valid               (M_AXI_RVALID),
	    .rd_ready               (M_AXI_RREADY),
	    
	    .wr_req_addr            (dma_axi_awaddr),
	    .wr_req_len             (dma_axi_awlen),
	    .wr_req_valid           (M_AXI_AWVALID),
	    .wr_req_ready           (M_AXI_AWREADY),
	    .wr_data                (M_AXI_WDATA),
	    .wr_valid               (M_AXI_WVALID),
	    .wr_ready               (M_AXI_WREADY),
	    .wr_last                (M_AXI_WLAST),
	    
	    .fifo_rden              (fifo_rden),
	    .fifo_wdata             (fifo_wdata),
	    .fifo_wen               (fifo_wen),
	    .fifo_rdata             (fifo_rdata),
	    .fifo_is_empty          (fifo_is_empty),
	    .fifo_is_full           (fifo_is_full)
  );

  fifo #(
	  .DATA_WIDTH    (32),
	  .ADDR_WIDTH    (8)
  ) u_buffer (
	  .reset     (M_AXI_ARESET),
	  .clk       (M_AXI_ACLK),
	  
	  .pop       (fifo_rden),
	  .data_in   (fifo_wdata),
	  .push      (fifo_wen),
	  .data_out  (fifo_rdata),
	  
	  .empty     (fifo_is_empty),
	  .full      (fifo_is_full)
  );

endmodule

