//======================================================================
// bm_core.v — Box-Muller core (Boutillon ICECS'00 eq.4-7)
//----------------------------------------------------------------------
// Bit-exact với MATLAB golden: box_muller_fixed.m
//
// LUỒNG:
//   1. urng -> lzc32 -> lz_count
//   2. r_idx   = min(lz_count >> 2, K-1)          (K=5 -> max r_idx=4)
//      s_start = 28 - r_idx*4
//      s       = (urng >> s_start) & 4'hF
//      s_prime = urng[7:0]
//      sign    = urng[8]
//   3. fr_val = Fr[r_idx, s]   (FR_W=9 bit unsigned, Q2.7)
//      g_val  = G[s_prime]     (G_W=9 bit signed,  Q1.7)
//   4. P_full = fr_val * g_val            (9u*9s -> 19-bit signed an toàn)
//   5. P_round = round_half_up(P_full, 8) = (P_full + 128) >>> 8   (arith)
//   6. sign=0 -> bm = P_round
//      sign=1 -> bm = -P_round - 1        (Boutillon eq.7, 1's-comp mean shift)
//   7. saturate to 16-bit signed (Q1.6)
//
// SHIFT=8 vì m+m'-B = 7+7-6 = 8.
//
// round_half_up với số ÂM: MATLAB floor((P+128)/256). >>> trong Verilog là
//   arithmetic shift = floor toward -inf cho signed -> KHỚP floor() của MATLAB.
//   (Đã kiểm chứng: floor((P+128)/256) == (P+128) >>> 8 với mọi P signed.)
//
// PIPE (tối ưu Fmax, mặc định 0):
//   PIPE=0: 1 stage — extract+ROM+mult+round+sat trong 1 cloud, đăng ký bm_out.
//           Latency 1 cycle (giữ nguyên hành vi cũ, khớp mọi golden/TB hiện có).
//   PIPE=1: 2 stage — stage A đăng ký {fr_val, g_val, sign}; stage B mult+
//           round+sign+sat rồi đăng ký bm_out. Cắt critical path
//           (LZC+shift+ROM) khỏi (mult+round). Latency 2 cycles.
//           Giá trị output KHÔNG đổi (chỉ trễ thêm 1 cycle); mọi TB
//           valid-driven vẫn PASS nguyên trạng.
//======================================================================
`timescale 1ns/1ps

module bm_core #(
    parameter K     = 5,
    parameter FR_W  = 9,     // Fr unsigned width
    parameter G_W   = 9,     // G signed width
    parameter B     = 6,
    parameter M     = 7,
    parameter M_P   = 7,
    parameter BM_W  = 16,    // output width (signed Q1.6 in int16 container)
    parameter PIPE  = 0      // 0 = 1-stage (mặc định), 1 = 2-stage pipeline
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  en,
    input  wire [31:0]           urng,
    // ROM interface (kết nối ngoài tới fr_rom / g_rom)
    output wire [2:0]            r_idx_o,    // -> fr_rom.r_idx
    output wire [3:0]            s_o,        // -> fr_rom.s
    output wire [7:0]            s_prime_o,  // -> g_rom.s_prime
    input  wire [FR_W-1:0]       fr_val,     // <- fr_rom.fr_val (unsigned)
    input  wire signed [G_W-1:0] g_val,      // <- g_rom.g_val (signed)
    output reg  signed [BM_W-1:0] bm_out,
    output reg                   valid
);

    localparam integer SHIFT = M + M_P - B;   // = 8

    // ---- Step 1: leading zero count ----
    wire [5:0] lz;
    lzc32 u_lzc (.in(urng), .lz(lz));

    // ---- Step 2: derive r_idx, s, s', sign ----
    wire [5:0] r_idx_full = (lz >> 2);                  // lz/4
    wire [2:0] r_idx      = (r_idx_full > (K-1)) ? (K-1) : r_idx_full[2:0];
    wire [4:0] s_start    = 5'd28 - {r_idx, 2'b00};     // 28 - r_idx*4
    wire [3:0] s_seg      = (urng >> s_start) & 4'hF;
    wire [7:0] s_prime    = urng[7:0];
    wire       sign_bit   = urng[8];

    assign r_idx_o   = r_idx;
    assign s_o       = s_seg;
    assign s_prime_o = s_prime;

    // ---- Chọn toán hạng cho phần nhân (theo PIPE) ----
    reg  [FR_W-1:0]      fr_q;
    reg  signed [G_W-1:0] g_q;
    reg                  sign_q;
    reg                  va;      // valid stage A (chỉ dùng khi PIPE=1)

    wire [FR_W-1:0]       fr_mul   = (PIPE != 0) ? fr_q   : fr_val;
    wire signed [G_W-1:0] g_mul    = (PIPE != 0) ? g_q    : g_val;
    wire                  sign_mul = (PIPE != 0) ? sign_q : sign_bit;
    wire                  en_mul   = (PIPE != 0) ? va     : en;

    // ---- Step 4: multiply (Fr unsigned x G signed) ----
    // Mở rộng fr thành signed (thêm bit 0 ở MSB) để nhân signed*signed.
    wire signed [FR_W:0]     fr_s    = {1'b0, fr_mul};      // (FR_W+1) bits, >=0
    wire signed [FR_W+G_W:0] p_full  = fr_s * g_mul;        // signed product

    // ---- Step 5: round-half-up by SHIFT (arith shift = floor) ----
    wire signed [FR_W+G_W:0] p_round = (p_full + (1 <<< (SHIFT-1))) >>> SHIFT;

    // ---- Step 6: apply sign (eq.7) ----
    wire signed [FR_W+G_W:0] bm_pre = sign_mul ? (-p_round - 1) : p_round;

    // ---- Step 7: saturate to BM_W signed ----
    localparam signed [BM_W-1:0] BM_MAX = (1 <<< (BM_W-1)) - 1;   // +32767
    localparam signed [BM_W-1:0] BM_MIN = -(1 <<< (BM_W-1));      // -32768
    wire signed [BM_W-1:0] bm_sat =
        (bm_pre >  BM_MAX) ? BM_MAX :
        (bm_pre <  BM_MIN) ? BM_MIN : bm_pre[BM_W-1:0];

    // ---- Registers ----
    // PIPE=0: bm_out <= bm_sat khi en (ROM phải combinational, đọc cùng cycle).
    // PIPE=1: stage A bắt {fr,g,sign} khi en; stage B đăng ký bm_out khi va.
    always @(posedge clk) begin
        if (!rst_n) begin
            fr_q   <= {FR_W{1'b0}};
            g_q    <= {G_W{1'b0}};
            sign_q <= 1'b0;
            va     <= 1'b0;
            bm_out <= {BM_W{1'b0}};
            valid  <= 1'b0;
        end else begin
            // stage A (chỉ có tác dụng khi PIPE=1)
            fr_q   <= fr_val;
            g_q    <= g_val;
            sign_q <= sign_bit;
            va     <= en;
            // stage B / output
            if (en_mul) begin
                bm_out <= bm_sat;
                valid  <= 1'b1;
            end else begin
                valid  <= 1'b0;
            end
        end
    end

endmodule
