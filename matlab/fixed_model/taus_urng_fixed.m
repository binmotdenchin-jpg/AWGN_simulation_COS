%% taus_urng_fixed.m — Tausworthe URNG (Fixed-Point, Bit-Exact with Verilog)
%
% KHÁC BIỆT QUAN TRỌNG so với taus_urng.m trong float_model:
%   - Float model: output là double trong [0,1), dùng cho thuật toán
%   - Fixed model: output là UINT32 (32-bit unsigned), BIT-EXACT với Verilog
%
% Đây là phiên bản sẽ làm GOLDEN cho RTL taus_urng.v.
%
% Verilog equivalent (xem rtl/src/taus_urng.v):
%   wire [31:0] b1, s1_next;
%   assign b1      = ((s1 << 13) ^ s1) >> 19;
%   assign s1_next = ((s1 & 32'hFFFFFFFE) << 12) ^ b1;
%   ...same for s2, s3...
%   wire [31:0] rng_out = s1_next ^ s2_next ^ s3_next;
%
% Reference: L'Ecuyer 1996, Fig.1 (taus88)
%
% Author: [Tên bạn]
% Date:   2026-05-20

function [rng_seq, state_log] = taus_urng_fixed(N, seed)
% Generate N samples of combined Tausworthe URNG.
%
% Inputs:
%   N    : number of samples to generate (positive integer)
%   seed : [s1, s2, s3] as uint32, must satisfy s1>1, s2>7, s3>15
%
% Outputs:
%   rng_seq   : N-by-1 uint32 array, output of combined URNG
%   state_log : N-by-3 uint32 array, [s1 s2 s3] state at each step
%               (dùng để verify từng component riêng lẻ)

    %% Input validation
    assert(numel(seed) == 3, 'Seed phải có 3 phần tử');
    assert(seed(1) > 1,  's1 phải > 1');
    assert(seed(2) > 7,  's2 phải > 7');
    assert(seed(3) > 15, 's3 phải > 15');
    
    s1 = uint32(seed(1));
    s2 = uint32(seed(2));
    s3 = uint32(seed(3));
    
    %% Pre-allocate output
    rng_seq   = zeros(N, 1, 'uint32');
    state_log = zeros(N, 3, 'uint32');
    
    %% Masks (constants)
    MASK1 = uint32(hex2dec('FFFFFFFE'));   % ~1
    MASK2 = uint32(hex2dec('FFFFFFF8'));   % ~7
    MASK3 = uint32(hex2dec('FFFFFFF0'));   % ~15
    
    %% Main loop — IDENTICAL to Verilog cycle-by-cycle
    for i = 1:N
        % Component 1: k=31, q=13, shifts=(13, 19, 12)
        b  = bitxor(bitshift_left32(s1, 13), s1);   % b = (s1 << 13) ^ s1
        b  = bitshift_right32(b, 19);               % b >>= 19
        s1_new = bitxor(bitshift_left32(bitand(s1, MASK1), 12), b);
        
        % Component 2: k=29, q=2, shifts=(2, 25, 4)
        b  = bitxor(bitshift_left32(s2, 2), s2);
        b  = bitshift_right32(b, 25);
        s2_new = bitxor(bitshift_left32(bitand(s2, MASK2), 4), b);
        
        % Component 3: k=28, q=3, shifts=(3, 11, 17)
        b  = bitxor(bitshift_left32(s3, 3), s3);
        b  = bitshift_right32(b, 11);
        s3_new = bitxor(bitshift_left32(bitand(s3, MASK3), 17), b);
        
        % Update state
        s1 = s1_new;
        s2 = s2_new;
        s3 = s3_new;
        
        % Log + output
        state_log(i, :) = [s1, s2, s3];
        rng_seq(i) = bitxor(bitxor(s1, s2), s3);
    end
end

%--------------------------------------------------------------------
function y = bitshift_left32(x, n)
% Left shift uint32, drop bits beyond 32 (giả lập Verilog wire wrap-around).
%
% MATLAB bitshift(uint32, +n) tự động xử lý overflow, nhưng để rõ ràng
% và an toàn, ta mask kết quả với 0xFFFFFFFF.

    y = bitand(bitshift(x, n), uint32(hex2dec('FFFFFFFF')));
end

%--------------------------------------------------------------------
function y = bitshift_right32(x, n)
% Right shift uint32 (logical shift, không phải arithmetic).

    y = bitshift(x, -n);
end
