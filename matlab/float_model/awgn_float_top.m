%% awgn_float_top.m — Top-level AWGN Generator (floating-point reference)
%
% Pipeline đầy đủ: Tausworthe URNG → Box-Muller → CLT Accumulator → N(0,1)
%
% Usage:
%   [noise, debug] = awgn_float_top(N, seed, A)
%   - N:      số output samples (phải chia hết cho A)
%   - seed:   [s1, s2, s3] cho Tausworthe URNG
%   - A:      CLT accumulation factor (mặc định 4)
%   - noise:  Nx1 vector ~ N(0,1)
%   - debug:  struct chứa intermediate signals (u0, u1, bm_x0, bm_x1, ...)
%
% Author: [Tên bạn]
% Date:   2026-05-20

function [noise, debug] = awgn_float_top(N, seed, A)
    if nargin < 3
        A = 4;
    end
    if nargin < 2
        seed = [uint32(12345), uint32(67891), uint32(11213)];
    end
    
    % Mỗi output sample cần A Box-Muller samples
    % Mỗi BM call sinh 2 samples (x0, x1) từ 2 uniform
    % Vậy cần N*A BM samples → N*A/2 BM calls → N*A uniform samples
    N_bm = N * A;         % tổng BM samples cần
    N_uniform = N_bm;     % mỗi pair (u0,u1) → 2 BM samples, nên cần N_bm uniform
    
    %% Step 1: Generate uniform random numbers
    fprintf('[1/3] Generating %d uniform samples (Tausworthe URNG)...\n', N_uniform);
    [u_all, final_state] = taus_urng(N_uniform, seed);
    
    % Chia thành cặp u0, u1
    u0 = u_all(1:2:end);   % odd indices
    u1 = u_all(2:2:end);   % even indices
    
    %% Step 2: Box-Muller transform
    fprintf('[2/3] Box-Muller transform → %d Gaussian samples...\n', N_bm);
    [bm_x0, bm_x1] = box_muller(u0, u1);
    
    % Interleave x0 và x1 thành 1 stream
    bm_all = zeros(N_bm, 1);
    bm_all(1:2:end) = bm_x0;
    bm_all(2:2:end) = bm_x1;
    
    %% Step 3: CLT Accumulation + Normalization
    fprintf('[3/3] CLT accumulation (A=%d) → %d output samples...\n', A, N);
    noise = clt_acc(bm_all, A);
    
    fprintf('Done. Output: %d samples, mean=%.4f, std=%.4f\n', ...
            length(noise), mean(noise), std(noise));
    
    %% Debug info
    if nargout > 1
        debug.u_all = u_all;
        debug.u0 = u0;
        debug.u1 = u1;
        debug.bm_x0 = bm_x0;
        debug.bm_x1 = bm_x1;
        debug.bm_all = bm_all;
        debug.final_urng_state = final_state;
        debug.params.A = A;
        debug.params.seed = seed;
        debug.params.N_output = N;
    end
end
