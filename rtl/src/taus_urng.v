//======================================================================
// taus_urng.v — Combined Tausworthe URNG (L'Ecuyer 1996, taus88)
//----------------------------------------------------------------------
// Bit-exact với MATLAB golden: matlab/fixed_model/taus_urng_fixed.m
//
// 3-component combined Tausworthe generator, period ~= 2^88.
// Mỗi cycle (khi en=1) cập nhật state và xuất 1 word 32-bit.
//
// Recurrence của từng component (khớp 100% MATLAB):
//   Comp1 (k=31): b = ((s1<<13) ^ s1) >> 19;  s1 = ((s1 & MASK1)<<12) ^ b;
//   Comp2 (k=29): b = ((s2<<2 ) ^ s2) >> 25;  s2 = ((s2 & MASK2)<<4 ) ^ b;
//   Comp3 (k=28): b = ((s3<<3 ) ^ s3) >> 11;  s3 = ((s3 & MASK3)<<17) ^ b;
//   out = s1 ^ s2 ^ s3;
//
//   MASK1=32'hFFFFFFFE (~1), MASK2=32'hFFFFFFF8 (~7), MASK3=32'hFFFFFFF0 (~15)
//
// LƯU Ý SHIFT: MATLAB <<13 rồi mask 0xFFFFFFFF (wrap 32-bit). Verilog wire
//   32-bit tự wrap khi gán nên các bit tràn bị bỏ — hành vi giống hệt.
//
// Reset: nạp seed s1>1, s2>7, s3>15 (constraint L'Ecuyer, xem design_decisions §4)
//
// Ref: L'Ecuyer 1996, Fig.1 (taus88)
//======================================================================
`timescale 1ns/1ps

module taus_urng #(
    parameter [31:0] SEED1 = 32'h00003039,   // 12345
    parameter [31:0] SEED2 = 32'h00010933,   // 67891
    parameter [31:0] SEED3 = 32'h00002BCD    // 11213
)(
    input  wire        clk,
    input  wire        rst_n,     // active-LOW synchronous reset (nạp seed)
    input  wire        en,        // enable: 1 = advance state, 0 = hold
    output reg  [31:0] rng_out,   // combined URNG output (registered)
    output wire        valid      // strobe: 1 khi rng_out VỪA cập nhật cycle này
);

    // State registers
    reg [31:0] s1, s2, s3;
    reg        valid_r;

    // Masks
    localparam [31:0] MASK1 = 32'hFFFFFFFE;
    localparam [31:0] MASK2 = 32'hFFFFFFF8;
    localparam [31:0] MASK3 = 32'hFFFFFFF0;

    // Combinational next-state (logical shifts; 32-bit wires auto-wrap on <<)
    wire [31:0] b1 = (((s1 << 13) ^ s1) >> 19);
    wire [31:0] b2 = (((s2 << 2 ) ^ s2) >> 25);
    wire [31:0] b3 = (((s3 << 3 ) ^ s3) >> 11);

    wire [31:0] s1_next = ((s1 & MASK1) << 12) ^ b1;
    wire [31:0] s2_next = ((s2 & MASK2) << 4 ) ^ b2;
    wire [31:0] s3_next = ((s3 & MASK3) << 17) ^ b3;

    always @(posedge clk) begin
        if (!rst_n) begin
            s1      <= SEED1;
            s2      <= SEED2;
            s3      <= SEED3;
            rng_out <= 32'b0;
            valid_r <= 1'b0;
        end else if (en) begin
            s1      <= s1_next;
            s2      <= s2_next;
            s3      <= s3_next;
            rng_out <= s1_next ^ s2_next ^ s3_next;  // khớp MATLAB: xuất state SAU cập nhật
            valid_r <= 1'b1;
        end else begin
            // FIX: valid là strobe "rng_out vừa được cập nhật cycle này".
            // Trước đây valid giữ mức 1 khi en=0 khiến bm_core/clt_acc phía sau
            // tiếp tục tiêu thụ lại cùng một word cũ -> output sai khi pipeline
            // tạm dừng giữa chừng (đã kiểm chứng bằng co-sim: 1969/2000 mismatch).
            valid_r <= 1'b0;
        end
    end

    assign valid = valid_r;

endmodule
