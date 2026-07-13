%% box_muller_fixed.m — Box-Muller Core (Fixed-Point, Boutillon Method)
%
% Đây là TRÁI TIM của fixed-point model. Phải khớp 100% với bm_core.v.
%
% LUỒNG XỬ LÝ:
%
%   ┌──────────────┐
%   │ URNG 32-bit  │ ─────┐
%   └──────────────┘      │
%                         ▼
%                  ┌──────────────┐
%                  │ Bit extract: │
%                  │  - Count LZ  │──→ r (partition level, 3-bit)
%                  │  - bits[s]   │──→ s (sub-segment, 4-bit)
%                  │  - bits[s']  │──→ s' (cosine index, 8-bit)
%                  │  - bits[sgn] │──→ sign (1-bit)
%                  └──────────────┘
%                         │
%                ┌────────┴────────┐
%                ▼                 ▼
%        ┌────────────┐    ┌────────────┐
%        │ Fr[r,s]    │    │ G[s']      │
%        │ (9-bit)    │    │ (8-bit sgn)│
%        └────────────┘    └────────────┘
%                 │                │
%                 └────────┬───────┘
%                          ▼
%                   ┌──────────────┐
%                   │  Multiply    │  P = Fr × G
%                   │  9 × 8 = 17  │
%                   └──────────────┘
%                          │
%                          ▼
%                   ┌──────────────┐
%                   │ Truncate to  │  Shift right (m + m' - B) = 8 bits
%                   │ Q(2.B) = 8b  │
%                   └──────────────┘
%                          │
%                          ▼
%                   ┌──────────────┐
%                   │ Apply sign   │  n = (1-2·sign)·P - sign
%                   │ (eq.7)       │
%                   └──────────────┘
%                          │
%                          ▼
%                      BM output
%                  (8-bit signed, Q(1.B))
%
% BIT-WIDTH ANALYSIS:
%   - Fr ROM:    9 bits unsigned, Q(2.7)        → max = 4 (sigma)
%   - G ROM:     8 bits signed,   Q(1.7)        → range ±√2
%   - P = Fr×G:  17 bits signed,  Q(3.14)       → max ≈ 4·√2 ≈ 5.66
%   - Truncate:  shift right (7+7-6) = 8 bits → Q(3.6) ≈ 9 bits signed
%   - Final BM:  apply sign and saturate → 7 bits signed, Q(1.6)
%
% NOTES:
%   - Phải dùng round-half-up khi truncate (xem design_decisions.md §3)
%   - sign manipulation theo eq.(7): n = (1-2·sign)·P - sign
%     → khi sign=0: n = P
%     → khi sign=1: n = -P - 1   (1's complement, không phải 2's complement)
%   - Lý do dùng 1's complement: để mean của output là -2^(-B-1) thay vì 0
%     (sẽ được CLT bù lại) — xem Boutillon eq.(9)
%
% Author: [Tên bạn]
% Date:   2026-05-20
% Ref:    Boutillon ICECS'00 eq.(4)-(7)

function [bm_out, debug] = box_muller_fixed(urng_val, fr_table, g_table)
% Compute one Box-Muller sample from 32-bit URNG output.
%
% Inputs:
%   urng_val  : uint32 (32-bit URNG output)
%   fr_table  : K × 16 integer matrix (from fr_rom_gen)
%   g_table   : 256 × 1 integer vector (from g_rom_gen)
%
% Outputs:
%   bm_out    : int16 (Box-Muller sample, Q(1.B) signed)
%   debug     : struct with intermediate values for verification

    %% Parameters (phải khớp với Verilog)
    B   = 6;     % Box-Muller output fraction bits
    m   = 7;     % Fr ROM fraction bits
    m_p = 7;     % G ROM fraction bits
    K   = 5;     % Fr partition levels
    
    %% Step 1: Extract bits from URNG output
    %
    % URNG = [b31 b30 b29 ... b1 b0]
    %
    % Bit allocation (32 bits total):
    %   - bits[31:K+3] : used for counting leading zeros (xác định r)
    %     With K=5, dùng bits[31..8] = 24 bits cho LZ count
    %   - bits[s..s-3] : 4-bit sub-segment s (depends on r)
    %   - bits[7:0]    : 8-bit cosine index s'
    %   - bit[bit_for_sign] : 1-bit sign
    %
    % SIMPLIFIED bit allocation (theo Boutillon):
    %   - Đếm leading zeros của bits[31:K+8] để xác định r
    %   - Sau LZ run là 4 bits cho s
    %   - bits[7:0] = s'
    %   - Một bit nào đó = sign (dùng bit[8] do còn dư)
    
    urng_u32 = uint32(urng_val);
    bits = bitget(urng_u32, 32:-1:1);   % bits(1)=MSB, bits(32)=LSB
    
    % Đếm leading zeros (count bits[1..N] are 0)
    % r = 1 nghĩa là bit[31]=1 (không có leading zero)
    % r = 2 nghĩa là bits[31:28]=0000, bit[27]=1
    % ...
    % r = K nghĩa là bits[31:..]=0 (K-1)*4 bits đầu là 0
    %
    % Cách tính: r = floor(lz/4) + 1, capped at K
    lz_count = 0;
    for i = 1:32
        if bits(i) == 1
            break;
        end
        lz_count = lz_count + 1;
    end
    
    r = min(floor(lz_count / 4) + 1, K);
    
    % s = 4 bits ngay sau leading zeros
    % Nếu r=1: s = bits[27:24] (top 4 of bits[27:0])
    % Nếu r=2: s = bits[23:20]
    % ...
    s_start_bit = 32 - (r * 4);   % MSB position (0-indexed) of s
    s = double(bitand(bitshift(urng_u32, -s_start_bit), uint32(15)));
    
    % s' = bits[7:0]
    s_prime = double(bitand(urng_u32, uint32(255)));
    
    % sign = bit[8]
    sign_bit = double(bitand(bitshift(urng_u32, -8), uint32(1)));
    
    %% Step 2: ROM lookup
    fr_val = fr_table(r, s + 1);     % MATLAB 1-indexed
    g_val  = g_table(s_prime + 1);
    
    %% Step 3: Multiply
    % Fr (9-bit unsigned) × G (8-bit signed) = 17-bit signed
    P_full = fr_val * g_val;
    
    %% Step 4: Truncate to Q(_.B)
    % Hiện tại P_full ở Q(3.14) (sau khi nhân Fr×G).
    % Truncate xuống Q(3.B) = Q(3.6): shift right (m + m_p - B) = 8 bits
    %
    % CRITICAL: Phải dùng round-half-up, không phải truncate thuần.
    % round-half-up: P >> shift = floor((P + 2^(shift-1)) / 2^shift)
    
    shift = m + m_p - B;
    P_rounded = round_half_up_int(P_full, shift);
    
    %% Step 5: Apply sign (Boutillon eq.7)
    % n = (1 - 2·sign) · P - sign
    %   nếu sign=0: n = P
    %   nếu sign=1: n = -P - 1
    if sign_bit == 0
        bm_out = P_rounded;
    else
        bm_out = -P_rounded - 1;
    end
    
    %% Saturate to int16 (đảm bảo không overflow)
    bm_out = max(min(bm_out, 2^15 - 1), -2^15);
    bm_out = int16(bm_out);
    
    %% Debug info
    debug.urng_val   = urng_val;
    debug.lz_count   = lz_count;
    debug.r          = r;
    debug.s          = s;
    debug.s_prime    = s_prime;
    debug.sign_bit   = sign_bit;
    debug.fr_val     = fr_val;
    debug.g_val      = g_val;
    debug.P_full     = P_full;
    debug.P_rounded  = P_rounded;
    debug.bm_out     = double(bm_out);
    
    % Conversion về float để verify
    debug.bm_float   = double(bm_out) / 2^B;
end

%--------------------------------------------------------------------
function y = round_half_up_int(x, shift)
% Round integer x right by `shift` bits with round-half-up convention.
%
% Equivalent to floor((x + 2^(shift-1)) / 2^shift)
%
% Verilog: y = (x + (1 << (shift-1))) >>> shift
%
% Note: Với signed input và shift dương, đây là "arithmetic shift right
% with rounding". Phép cộng 2^(shift-1) đảm bảo 0.5 → 1 (round up).

    if shift <= 0
        y = x;
        return;
    end
    
    half = 2^(shift - 1);
    y = floor((x + half) / 2^shift);
end
