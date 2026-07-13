//======================================================================
// awgn_top.v — AWGN Generator Top-Level (Boutillon Box-Muller + CLT)
//----------------------------------------------------------------------
// Ghép: taus_urng -> bm_core (+ fr_rom, g_rom) -> clt_acc
//
// Dataflow & timing:
//   stage0: URNG xuất rng_out (registered, valid khi en)
//   stage0(comb): bm_core đọc ROM combinational cùng cycle, tính bm_sat
//   stage1: bm_core đăng ký bm_out + bm_valid (1 cycle sau urng valid)
//   stageN: clt_acc gom A=4 bm_out -> noise_out + noise_valid
//
// Mỗi noise_out hợp lệ cần A=4 URNG cycles. Throughput = 1/A sample/cycle.
//
// Interface đơn giản (valid-only, không backpressure). Có thể bọc AXI-Stream
// ở lớp ngoài nếu cần.
//======================================================================
`timescale 1ns/1ps

module awgn_top #(
    parameter [31:0] SEED1 = 32'h00003039,   // 12345
    parameter [31:0] SEED2 = 32'h00010933,   // 67891
    parameter [31:0] SEED3 = 32'h00002BCD,   // 11213
    parameter K       = 5,
    parameter FR_W    = 9 ,
    parameter G_W     = 9,
    parameter B       = 6,
    parameter M       = 7,
    parameter M_P     = 7,
    parameter A       = 4,
    parameter BM_W    = 16,
    parameter OUT_W   = 16,
    parameter PIPE    = 0,                   // 1 = bm_core 2-stage (tối ưu Fmax)
    parameter FR_INIT = "fr_table.txt",
    parameter G_INIT  = "g_table.txt"
)(
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    en,          // chạy pipeline
    output wire signed [OUT_W-1:0] noise_out,   // mẫu N(0,1) scaled 2^B (Q2.6)
    output wire                    noise_valid
);

    //------------------------------------------------------------------
    // 1) Tausworthe URNG
    //------------------------------------------------------------------
    wire [31:0] urng;
    wire        urng_valid;

    taus_urng #(
        .SEED1(SEED1), .SEED2(SEED2), .SEED3(SEED3)
    ) u_urng (
        .clk(clk), .rst_n(rst_n), .en(en),
        .rng_out(urng), .valid(urng_valid)
    );

    //------------------------------------------------------------------
    // 2) Box-Muller core + ROMs (combinational ROM, registered bm_out)
    //------------------------------------------------------------------
    wire [2:0]            r_idx;
    wire [3:0]            s_seg;
    wire [7:0]            s_prime;
    wire [FR_W-1:0]       fr_val;
    wire signed [G_W-1:0] g_val;

    wire signed [BM_W-1:0] bm_out;
    wire                   bm_valid;

    fr_rom #(.K(K), .FR_W(FR_W), .INITFILE(FR_INIT)) u_fr (
        .r_idx(r_idx), .s(s_seg), .fr_val(fr_val)
    );

    g_rom #(.G_W(G_W), .INITFILE(G_INIT)) u_g (
        .s_prime(s_prime), .g_val(g_val)
    );

    bm_core #(
        .K(K), .FR_W(FR_W), .G_W(G_W), .B(B), .M(M), .M_P(M_P), .BM_W(BM_W),
        .PIPE(PIPE)
    ) u_bm (
        .clk(clk), .rst_n(rst_n), .en(urng_valid),
        .urng(urng),
        .r_idx_o(r_idx), .s_o(s_seg), .s_prime_o(s_prime),
        .fr_val(fr_val), .g_val(g_val),
        .bm_out(bm_out), .valid(bm_valid)
    );

    //------------------------------------------------------------------
    // 3) CLT accumulator
    //------------------------------------------------------------------
    clt_acc #(
        .A(A), .B(B), .BM_W(BM_W), .OUT_W(OUT_W)
    ) u_clt (
        .clk(clk), .rst_n(rst_n),
        .bm_valid(bm_valid), .bm_in(bm_out),
        .clt_out(noise_out), .out_valid(noise_valid)
    );

endmodule
