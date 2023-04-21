`timescale 10ns / 1ns

module adder_test_g();
        reg [7:0] op1, op2;
        wire [7:0] sum;

        adder a1 (
                .operand0(op1),
                .operand1(op2),
                .result(sum)
        );

        initial
        begin
                op1 = 8'd0;
                op2 = 8'd0;
                #1000
                $display("CAIXUKUN!!!\n");
                $finish;
        end

        always #20
        begin

                op1 = {$random} % 256;
                op2 = {$random} % 256;

        end

        initial
        begin            
                $dumpfile("adder_tb.vcd");        //生成的vcd文件名称
                $dumpvars(0, adder_test_g);    		//tb模块名称
        end
endmodule
