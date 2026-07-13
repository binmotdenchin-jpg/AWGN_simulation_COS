%% clt_acc_fixed.m — CLT Accumulator (Fixed-Point)
%
% Tích lũy A=4 samples Box-Muller → 1 output sample, với mean compensation.
%
% LUỒNG XỬ LÝ:
%
%   bm[0] ─┐
%   bm[1] ─┼─→ Σ (sum) ──→ [mean compensation] ──→ [scale] ──→ output
%   bm[2] ─┤
%   bm[3] ─┘
%
% BIT-WIDTH ANALYSIS:
%   - BM input:        7 bits signed, Q(1.6),  range ≈ ±2
%   - Sum of A=4:      9 bits signed, Q(3.6),  range ≈ ±8
%   - After mean comp: 9 bits signed
%   - After scale:     8 bits signed, Q(2.6)
%
% MEAN COMPENSATION (Boutillon eq.9):
%   Mỗi BM sample có mean = -2^(-B-1) (do sign manipulation eq.7 dùng 1's comp)
%   Sau khi sum A samples: mean = -A · 2^(-B-1)
%
%   Với A=4, B=6:
%     mean_offset = -4 · 2^(-7) = -1/32 = -0.03125
%   Trong Q(_.6) format: -1/32 × 64 = -2 (integer)
%
%   → Compensation: cộng +2 vào sum để mean về 0
%
% SCALING (normalize std to 1):
%   Sau CLT, std = √A = √4 = 2
%   → Để output có std = 1, chia 2 (right-shift 1 bit, free trong hardware)
%
% ALTERNATIVE: nếu muốn output có std = σ_target (channel emulation):
%   output = (sum + mean_offset) × (σ_target / √A)
%   Có thể dùng external multiplier hoặc shift+add tổ hợp.
%
% Author: [Tên bạn]
% Date:   2026-05-20
% Ref:    Boutillon ICECS'00 eq.(9), (10)

function [clt_out, debug] = clt_acc_fixed(bm_samples)
% Accumulate A samples of Box-Muller fixed-point output.
%
% Inputs:
%   bm_samples : A×1 int16 vector (Box-Muller output from box_muller_fixed)
%                With A=4, B=6: each sample is Q(1.6) signed, range ±2
%
% Outputs:
%   clt_out  : int16 (Q(2.6) signed, ~N(0,1) approximation)
%   debug    : struct with intermediate values

    %% Parameters (phải khớp Verilog)
    A = 4;     % accumulation factor
    B = 6;     % fraction bits
    
    assert(length(bm_samples) == A, 'Cần đúng A=%d samples', A);
    
    %% Step 1: Sum
    % Mỗi BM sample là int16, sum của 4 samples sẽ trong khoảng (-8, 8)
    sum_val = int32(0);   % dùng int32 để tránh overflow
    for i = 1:A
        sum_val = sum_val + int32(bm_samples(i));
    end
    
    %% Step 2: Mean compensation
    % Cộng +A·1 = +4 (trong Q(_.6) units) để bù mean offset
    %
    % Giải thích: mỗi BM sample có mean -2^(-B-1) = -1/128 (trong float)
    % Trong Q(1.6) format: -1/128 × 64 = -0.5 (nhưng integer)
    % Wait, kiểm tra lại: 2^(-B-1) = 2^(-7) = 1/128
    % Trong Q(_.B=6) units: 1/128 × 2^6 = 1/2 (integer 0 hoặc làm tròn lên 1)
    %
    % Thực tế Boutillon dùng mean = -A·2^(-B-1) sau khi sum.
    % Với A=4, B=6: mean = -4/128 = -1/32
    % Trong Q(_.B=6) units: -1/32 × 64 = -2 (integer)
    % → Cộng +2 để bù.
    
    mean_offset = A * 2^(-B-1);          % float value
    mean_comp_int = round(mean_offset * 2^B);   % to integer (Q(_.B) units)
    
    % Note: ở đây có thể đơn giản hóa = A/2 = 2 (với A=4, B=6)
    % Lý do: A·2^(-B-1) × 2^B = A·2^(-1) = A/2
    
    sum_compensated = sum_val + int32(mean_comp_int);
    
    %% Step 3: Scale (divide by √A = 2 → right shift 1 bit)
    % √A = 2 = 2^1, nên chia bằng right-shift 1 bit (round-half-up)
    
    scale_shift = log2(sqrt(A));   % = 1 với A=4
    
    if scale_shift == round(scale_shift) && scale_shift > 0
        % Right shift with round-half-up
        half = int32(2^(scale_shift - 1));
        scaled = idivide_round((sum_compensated + half), int32(2^scale_shift));
    else
        % Non-power-of-2 sqrt (A=2, 8...): cần multiplier
        scaled = idivide_round(sum_compensated * int32(2^B), ...
                               int32(round(sqrt(A) * 2^B)));
    end
    
    %% Step 4: Saturate to int16
    clt_out = int16(max(min(scaled, int32(2^15 - 1)), int32(-2^15)));
    
    %% Debug info
    debug.bm_samples = bm_samples;
    debug.sum_val = sum_val;
    debug.mean_comp_int = mean_comp_int;
    debug.sum_compensated = sum_compensated;
    debug.scale_shift = scale_shift;
    debug.scaled = scaled;
    debug.clt_out_int = double(clt_out);
    debug.clt_out_float = double(clt_out) / 2^B;
end

%--------------------------------------------------------------------
function y = idivide_round(x, d)
% Integer division with round-half-up (toward +Inf).
%
% MATLAB's idivide có nhiều mode (fix, floor, ceil, round) nhưng
% round mode là round-to-nearest-even, không phải round-half-up.
% Ta tự implement để đảm bảo bit-exact với Verilog.

    if d == 0
        error('Division by zero');
    end
    
    % Note: với d > 0 và đã được "round-half-up" qua việc cộng half trước đó,
    % chỉ cần floor division là OK.
    if d > 0
        y = idivide(x, d, 'floor');
    else
        % Trường hợp d < 0 (hiếm khi xảy ra trong design này)
        y = idivide(-x, -d, 'floor');
    end
end
