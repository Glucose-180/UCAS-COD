`timescale 10 ns / 1 ns

`define DATA_WIDTH 32
`define ADDR_WIDTH 5

module rf_tb();
    reg clk;
    reg [`ADDR_WIDTH - 1:0] waddr, raddr1, raddr2;
    reg [`DATA_WIDTH - 1:0] wdata;
    wire [`DATA_WIDTH - 1:0] rdata1, rdata2;
    integer i;

    reg_file rf1(clk, waddr, raddr1, raddr2, 1'b1, wdata, rdata1, rdata2);

    initial begin
        clk = 0;

        for (i = 0; i < 32; i = i + 1) begin
            waddr = i;
            wdata = i;
            #5
            clk = 1;
            #25
            clk = 0;
        end
    end

    initial begin
        wait (i >= 32);
        forever #20 begin
            raddr1 = {$random} % 32;
            raddr2 = {$random} % 32;
        end
    end

    initial begin
        #1600
        $finish;
    end

    initial begin
        $dumpfile("reg_file.vcd");
        $dumpvars(0, rf_tb);
    end

endmodule