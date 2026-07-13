//======================================================================
// clt_acc.v — CLT Accumulator (Boutillon ICECS'00 eq.9,10)
//----------------------------------------------------------------------
// Bit-exact với MATLAB golden: clt_acc_fixed.m
//
// Tích lũy A=4 mẫu Box-Muller liên tiếp -> 1 mẫu output ~ N(0,1) scaled 2^B.
//
//   sum        = bm[0]+bm[1]+bm[2]+bm[3]           (signed)
//   sum_comp   = sum + MEAN_COMP                   (MEAN_COMP = A/2 = 2)
//   scaled     = (sum_comp + 1) >>> 1              (round-half-up, /sqrt(A)=/2)
//   clt_out    = saturate16(scaled)
//
// MEAN_COMP = round(A*2^(-B-1) * 2^B) = A/2 = 2  (với A=4).
// SCALE_SHIFT = log2(sqrt(A)) = 1.
//
// Streaming FSM: nhận từng bm_in (bm_valid), đếm 0..A-1, khi đủ A thì
//   xuất clt_out + out_valid 1 cycle, rồi reset accumulator.
//
// Range: bm ~ ±2 (Q1.6 ~ ±128 int). sum 4 mẫu cần ~ 9-10 bits signed.
//   Dùng accumulator 20-bit cho dư.
//======================================================================
`timescale 1ns/1ps

module clt_acc #(
    parameter A         = 4,
    parameter B         = 6,
    parameter BM_W      = 16,    // input width (signed)
    parameter OUT_W     = 16,    // output width (signed Q2.6)
    parameter ACC_W     = 20
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   bm_valid,
    input  wire signed [BM_W-1:0] bm_in,
    output reg  signed [OUT_W-1:0] clt_out,
    output reg                    out_valid
);

    localparam signed [ACC_W-1:0] MEAN_COMP   = A/2;          // = 2
    localparam integer            SCALE_SHIFT = 1;            // log2(sqrt(4))

    reg signed [ACC_W-1:0] acc;
    reg [$clog2(A+1)-1:0]  cnt;

    // Combinational sum_comp + scale of the *completing* sample
    wire signed [ACC_W-1:0] sum_full   = acc + bm_in;        // sum khi nhận mẫu thứ A
    wire signed [ACC_W-1:0] sum_comp   = sum_full + MEAN_COMP;
    wire signed [ACC_W-1:0] scaled     = (sum_comp + (1 <<< (SCALE_SHIFT-1))) >>> SCALE_SHIFT;

    localparam signed [OUT_W-1:0] OMAX =  (1 <<< (OUT_W-1)) - 1;
    localparam signed [OUT_W-1:0] OMIN = -(1 <<< (OUT_W-1));
    wire signed [OUT_W-1:0] scaled_sat =
        (scaled > OMAX) ? OMAX :
        (scaled < OMIN) ? OMIN : scaled[OUT_W-1:0];

    always @(posedge clk) begin
        if (!rst_n) begin
            acc       <= {ACC_W{1'b0}};
            cnt       <= 0;
            clt_out   <= {OUT_W{1'b0}};
            out_valid <= 1'b0;
        end else begin
            out_valid <= 1'b0;
            if (bm_valid) begin
                if (cnt == A-1) begin
                    // sample cuối cùng của nhóm -> hoàn tất
                    clt_out   <= scaled_sat;
                    out_valid <= 1'b1;
                    acc       <= {ACC_W{1'b0}};
                    cnt       <= 0;
                end else begin
                    acc <= acc + bm_in;
                    cnt <= cnt + 1'b1;
                end
            end
        end
    end

endmodule
