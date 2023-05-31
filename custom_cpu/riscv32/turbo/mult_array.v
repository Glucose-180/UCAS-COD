
/* Multipiler using TRUE FORM
the high 32 bits are discared */
module multiplier (
    input [31:0] A,
    input [31:0] B,
    output [31:0] P
);

    wire [31:0] S0 [31:0];
    wire [31:0] S1 [15:0];
    wire [31:0] S2 [7:0];
    wire [31:0] S3 [3:0];
    wire [31:0] S4 [1:0];
    wire [31:0] S5;

    assign S0[0] = (B[0] ? A : 32'd0);
    assign S0[1] = { (B[1] ? A[30:0] : 31'd0),1'd0 };
    assign S0[2] = { (B[2] ? A[29:0] : 30'd0),2'd0 };
    assign S0[3] = { (B[3] ? A[28:0] : 29'd0),3'd0 };
    assign S0[4] = { (B[4] ? A[27:0] : 28'd0),4'd0 };
    assign S0[5] = { (B[5] ? A[26:0] : 27'd0),5'd0 };
    assign S0[6] = { (B[6] ? A[25:0] : 26'd0),6'd0 };
    assign S0[7] = { (B[7] ? A[24:0] : 25'd0),7'd0 };
    assign S0[8] = { (B[8] ? A[23:0] : 24'd0),8'd0 };
    assign S0[9] = { (B[9] ? A[22:0] : 23'd0),9'd0 };
    assign S0[10] = { (B[10] ? A[21:0] : 22'd0),10'd0 };
    assign S0[11] = { (B[11] ? A[20:0] : 21'd0),11'd0 };
    assign S0[12] = { (B[12] ? A[19:0] : 20'd0),12'd0 };
    assign S0[13] = { (B[13] ? A[18:0] : 19'd0),13'd0 };
    assign S0[14] = { (B[14] ? A[17:0] : 18'd0),14'd0 };
    assign S0[15] = { (B[15] ? A[16:0] : 17'd0),15'd0 };
    assign S0[16] = { (B[16] ? A[15:0] : 16'd0),16'd0 };
    assign S0[17] = { (B[17] ? A[14:0] : 15'd0),17'd0 };
    assign S0[18] = { (B[18] ? A[13:0] : 14'd0),18'd0 };
    assign S0[19] = { (B[19] ? A[12:0] : 13'd0),19'd0 };
    assign S0[20] = { (B[20] ? A[11:0] : 12'd0),20'd0 };
    assign S0[21] = { (B[21] ? A[10:0] : 11'd0),21'd0 };
    assign S0[22] = { (B[22] ? A[9:0] : 10'd0),22'd0 };
    assign S0[23] = { (B[23] ? A[8:0] : 9'd0),23'd0 };
    assign S0[24] = { (B[24] ? A[7:0] : 8'd0),24'd0 };
    assign S0[25] = { (B[25] ? A[6:0] : 7'd0),25'd0 };
    assign S0[26] = { (B[26] ? A[5:0] : 6'd0),26'd0 };
    assign S0[27] = { (B[27] ? A[4:0] : 5'd0),27'd0 };
    assign S0[28] = { (B[28] ? A[3:0] : 4'd0),28'd0 };
    assign S0[29] = { (B[29] ? A[2:0] : 3'd0),29'd0 };
    assign S0[30] = { (B[30] ? A[1:0] : 2'd0),30'd0 };
    assign S0[31] = { (B[31] ? A[0] : 1'd0),31'd0 };

    assign S1[0] = S0[0] + S0[1];
    assign S1[1] = S0[2] + S0[3];
    assign S1[2] = S0[4] + S0[5];
    assign S1[3] = S0[6] + S0[7];
    assign S1[4] = S0[8] + S0[9];
    assign S1[5] = S0[10] + S0[11];
    assign S1[6] = S0[12] + S0[13];
    assign S1[7] = S0[14] + S0[15];
    assign S1[8] = S0[16] + S0[17];
    assign S1[9] = S0[18] + S0[19];
    assign S1[10] = S0[20] + S0[21];
    assign S1[11] = S0[22] + S0[23];
    assign S1[12] = S0[24] + S0[25];
    assign S1[13] = S0[26] + S0[27];
    assign S1[14] = S0[28] + S0[29];
    assign S1[15] = S0[30] + S0[31];

    assign S2[0] = S1[0] + S1[1];
    assign S2[1] = S1[2] + S1[3];
    assign S2[2] = S1[4] + S1[5];
    assign S2[3] = S1[6] + S1[7];
    assign S2[4] = S1[8] + S1[9];
    assign S2[5] = S1[10] + S1[11];
    assign S2[6] = S1[12] + S1[13];
    assign S2[7] = S1[14] + S1[15];

    assign S3[0] = S2[0] + S2[1];
    assign S3[1] = S2[2] + S2[3];
    assign S3[2] = S2[4] + S2[5];
    assign S3[3] = S2[6] + S2[7];
    
    assign S4[0] = S3[0] + S3[1];
    assign S4[1] = S3[2] + S3[3];

    assign S5 = S4[0] + S4[1];
    assign P = S5;
endmodule