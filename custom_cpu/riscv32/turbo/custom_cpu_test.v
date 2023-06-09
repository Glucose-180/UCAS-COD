`timescale 1ns / 1ps

module custom_cpu_test
();

    reg	sys_clk;
	reg	sys_reset_n;

	initial begin
		sys_clk = 1'b0;
		sys_reset_n = 1'b0;
		# 100
		sys_reset_n = 1'b1;
	end
    
    always begin
	    # 5 sys_clk = ~sys_clk;
    end

	always begin
		# 20000000 $display("Simulated %d ns", $time);
	end

	cpu_test_top    u_cpu_test (
		.sys_clk	    (sys_clk),
		.sys_reset_n	(sys_reset_n)
	);
    
    `define MEM_WEN     u_cpu_test.u_cpu.MemWrite
    `define MEM_ADDR	u_cpu_test.u_cpu.Address
    `define MEM_WDATA	u_cpu_test.u_cpu.Write_data

    wire [31:0] pc_rt       = u_cpu_test.u_cpu.inst_retire[31:0 ];
    wire [31:0] rf_wdata_rt = u_cpu_test.u_cpu.inst_retire[63:32];
    wire [4 :0] rf_waddr_rt = u_cpu_test.u_cpu.inst_retire[68:64];
    wire        rf_en_rt    = u_cpu_test.u_cpu.inst_retire[69];

    reg  [31:0] pc_golden;
    reg  [31:0] rf_wdata_golden;
    reg  [4 :0] rf_waddr_golden;

    // Open trace file
    integer trace_file, type_num, ret;
    initial begin
        trace_file = $fopen(`TRACE_FILE, "r");
        if(trace_file == 0)
	    begin
		    $display("ERROR: open file failed.");
		    $fatal;
	    end
    end

    reg [31:0] PC_ref, new_PC_ref;
    reg [31:0] rf_bit_cmp_ref;
    reg [31:0] mem_addr_ref, mem_wdata_ref, mem_bit_cmp_ref;
    reg [ 3:0] mem_wstrb_ref;
    reg        mem_read_ref;

    reg trace_end;

    // Get golden records
    always @(posedge sys_clk) begin 
        if (~sys_reset_n)
            trace_end <= 1'b0;
        else begin
            if ($feof(trace_file))
                trace_end <= 1'b1;
            #1;
            if (has_compared) begin
            	if ($feof(trace_file))
                	trace_end <= 1'b1;

                ret = $fscanf(trace_file, "%d", type_num);
                ret = $fscanf(trace_file, "%h", pc_golden);
                case(type_num)
                1:  ret = $fscanf(trace_file, "%d %h %h %d", rf_waddr_golden, rf_wdata_golden, rf_bit_cmp_ref, mem_read_ref);
                2:	ret = $fscanf(trace_file, "%h %h %h %h", mem_addr_ref, mem_wstrb_ref, mem_wdata_ref, mem_bit_cmp_ref);
                3:	ret = $fscanf(trace_file, "%h", new_PC_ref);
                4:	ret = $fscanf(trace_file, "%h %d %h", new_PC_ref, rf_waddr_golden, rf_wdata_golden);
                default:
                begin
                    $display("ERROR: unknown type.");
                    $fclose(trace_file);
                    $fatal;
                end
                endcase

                while ((type_num != 1 || rf_waddr_golden == 5'b0) && type_num != 4 && !$feof(trace_file)) begin
                    if ($feof(trace_file))
                        trace_end <= 1'b1;

                    ret = $fscanf(trace_file, "%d", type_num);
                    ret = $fscanf(trace_file, "%h", pc_golden);
                    case(type_num)
                    1:  ret = $fscanf(trace_file, "%d %h %h %d", rf_waddr_golden, rf_wdata_golden, rf_bit_cmp_ref, mem_read_ref);
                    2:	ret = $fscanf(trace_file, "%h %h %h %h", mem_addr_ref, mem_wstrb_ref, mem_wdata_ref, mem_bit_cmp_ref);
                    3:	ret = $fscanf(trace_file, "%h", new_PC_ref);
                    4:	ret = $fscanf(trace_file, "%h %d %h", new_PC_ref, rf_waddr_golden, rf_wdata_golden);
                    default:
                    begin
                        $display("ERROR: unknown type.");
                        $fclose(trace_file);
                        $fatal;
                    end
                    endcase
                end
            end
        end
    end

    // Compare result
    reg has_compared;
    always @(posedge sys_clk)
    begin
        if (~sys_reset_n)
            has_compared <= 1'b1;
        else begin
            #3;
            if(rf_en_rt & rf_waddr_rt != 5'd0)
            begin
                if ((pc_rt !== pc_golden) || (rf_waddr_rt !== rf_waddr_golden) || ((rf_wdata_rt & rf_bit_cmp_ref) !== (rf_wdata_golden & rf_bit_cmp_ref)))
                begin
                    $display("===================================================================");
                    $display("ERROR: at %dns.", $time);
                    $display("Yours:     PC = 0x%8h, rf_waddr = 0x%2h, rf_wdata = 0x%8h", pc_rt, rf_waddr_rt, rf_wdata_rt);
                    $display("Reference: PC = 0x%8h, rf_waddr = 0x%2h, rf_wdata = 0x%8h", pc_golden, rf_waddr_golden, rf_wdata_golden);
                    $display("===================================================================");
                    $fclose(trace_file);
                    $fatal;
                end
                else
                    has_compared <= 1'b1;
            end
            else
                has_compared <= 1'b0;
        end
    end

    // End
    always @(posedge sys_clk)
    begin
        if (trace_end & (`MEM_WEN == 1'b1) & (`MEM_ADDR == 32'h0C) & (`MEM_WDATA == 32'h0))
        begin
            $display("=================================================");
            $display("Benchmark simulation passed!!!");
            $display("=================================================");
            $fclose(trace_file);
            $finish;
        end
    end

    reg [4095:0] dumpfile;
    initial begin
	    if ($value$plusargs("DUMP=%s", dumpfile))
	    begin
		    $dumpfile(dumpfile);
		    $dumpvars();
	    end
    end

endmodule
