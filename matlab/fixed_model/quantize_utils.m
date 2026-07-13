%% quantize_utils.m — Bit-Accurate Quantization Utilities
%
% Tập hợp các hàm quantization dùng chung cho fixed-point model.
% Mọi phép quantize trong dự án PHẢI dùng các hàm này để đảm bảo
% nhất quán giữa MATLAB và Verilog.
%
% Convention được chọn:
%   - Rounding mode: round-half-up (xem design_decisions.md §3)
%   - Overflow: saturation (clamp to min/max)
%   - Negative numbers: 2's complement
%
% Author: [Tên bạn]
% Date:   2026-05-20

function utils = quantize_utils()
    utils.round_half_up = @round_half_up;
    utils.saturate      = @saturate;
    utils.to_signed     = @to_signed;
    utils.from_signed   = @from_signed;
    utils.q_format      = @q_format;
    utils.bin2dec_signed = @bin2dec_signed;
    utils.dec2bin_signed = @dec2bin_signed;
end

%--------------------------------------------------------------------
function y = round_half_up(x)
% Round x to nearest integer, with ties rounded UP (toward +Inf).
%
% Examples:
%   round_half_up(2.5)  → 3
%   round_half_up(-2.5) → -2  (toward +Inf, không phải away from zero)
%   round_half_up(2.4)  → 2
%   round_half_up(2.6)  → 3
%
% Verilog equivalent:
%   assign y = (x + (1 << (M-K-1))) >>> (M-K);
%
% TẠI SAO chọn mode này: xem design_decisions.md §3

    y = floor(x + 0.5);
end

%--------------------------------------------------------------------
function y = saturate(x, n_bits, signed_flag)
% Saturate x to fit in n_bits.
%
%   y = saturate(x, n_bits, signed_flag)
%   - signed_flag = true:  range [-2^(n-1), 2^(n-1)-1]
%   - signed_flag = false: range [0, 2^n - 1]
%
% Examples:
%   saturate(150, 8, true)  → 127  (max signed 8-bit)
%   saturate(-150, 8, true) → -128 (min signed 8-bit)
%   saturate(300, 8, false) → 255  (max unsigned 8-bit)

    if signed_flag
        max_val = 2^(n_bits - 1) - 1;
        min_val = -2^(n_bits - 1);
    else
        max_val = 2^n_bits - 1;
        min_val = 0;
    end
    
    y = max(min(x, max_val), min_val);
end

%--------------------------------------------------------------------
function s = to_signed(u, n_bits)
% Convert unsigned integer interpretation to signed (2's complement).
%
% Verilog equivalent: $signed(u)
%
% Examples (8-bit):
%   to_signed(255, 8) → -1
%   to_signed(128, 8) → -128
%   to_signed(127, 8) → 127
%   to_signed(0, 8)   → 0

    threshold = 2^(n_bits - 1);
    if u >= threshold
        s = u - 2^n_bits;
    else
        s = u;
    end
end

%--------------------------------------------------------------------
function u = from_signed(s, n_bits)
% Convert signed value to unsigned bit-pattern (2's complement).
%
% Inverse of to_signed.
%
% Examples (8-bit):
%   from_signed(-1, 8)   → 255
%   from_signed(-128, 8) → 128
%   from_signed(127, 8)  → 127

    if s < 0
        u = s + 2^n_bits;
    else
        u = s;
    end
end

%--------------------------------------------------------------------
function y = q_format(x, n_int, n_frac, signed_flag)
% Convert floating-point x to Q(n_int.n_frac) fixed-point integer.
%
% Q-format: n_int bits cho phần nguyên, n_frac bits cho phần thập phân.
% Total = n_int + n_frac + (1 if signed) bits.
%
% Steps:
%   1. Scale by 2^n_frac
%   2. Round (half-up)
%   3. Saturate to fit in (n_int + n_frac) bits
%
% Example: Convert 1.5 to Q(2.6) signed format
%   q_format(1.5, 2, 6, true)
%   → scale: 1.5 * 64 = 96
%   → round: 96
%   → saturate: 96 (fits in 2+6+1 = 9 bits signed, range -256..255)
%   → return 96 (which represents 96/64 = 1.5)

    scaled = x * 2^n_frac;
    rounded = round_half_up(scaled);
    
    total_bits = n_int + n_frac;
    if signed_flag
        total_bits = total_bits + 1;  % thêm sign bit
    end
    
    y = saturate(rounded, total_bits, signed_flag);
end

%--------------------------------------------------------------------
function d = bin2dec_signed(b, n_bits)
% Convert binary string (with optional leading zeros) to signed decimal.
% Useful for Verilog $readmemb compatibility.
%
% Example: bin2dec_signed('11111111', 8) → -1

    u = bin2dec(b);
    d = to_signed(u, n_bits);
end

%--------------------------------------------------------------------
function b = dec2bin_signed(d, n_bits)
% Convert signed decimal to fixed-width binary string (2's complement).
%
% Example: dec2bin_signed(-1, 8) → '11111111'

    u = from_signed(d, n_bits);
    b = dec2bin(u, n_bits);
end
