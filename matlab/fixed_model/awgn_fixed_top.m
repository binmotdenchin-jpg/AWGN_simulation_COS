%% awgn_fixed_top.m — Top-Level AWGN Generator (Fixed-Point, Bit-Accurate)
%
% Pipeline đầy đủ:
%   Tausworthe URNG → Box-Muller fixed → CLT accumulator → noise output
%
% Đây là model BIT-EXACT với RTL Verilog. Output của hàm này sẽ làm
% golden reference để verify RTL.
%
% Author: [Tên bạn]
% Date:   2026-05-20

function [noise, debug] = awgn_fixed_top(N, seed)
% Generate N AWGN samples (fixed-point, bit-accurate).
%
% Inputs:
%   N    : số output samples (mỗi sample cần A=4 BM samples = A×1 URNG)
%   seed : [s1, s2, s3] uint32 cho Tausworthe URNG
%
% Outputs:
%   noise : N×1 int16 vector (Q(2.6) signed, ≈ N(0,1) scaled by 2^B)
%   debug : struct chứa toàn bộ intermediate signals (để verify RTL)

    if nargin < 2
        seed = [uint32(12345), uint32(67891), uint32(11213)];
    end
    
    %% Parameters
    A = 4;   % CLT accumulation factor
    B = 6;   % fraction bits
    
    %% Load ROM tables
    if ~exist('fr_table.mat', 'file')
        warning('fr_table.mat không tồn tại, đang tạo...');
        fr_rom_gen();
    end
    if ~exist('g_table.mat', 'file')
        warning('g_table.mat không tồn tại, đang tạo...');
        g_rom_gen();
    end
    
    load('fr_table.mat', 'fr_table');
    load('g_table.mat', 'g_table');
    
    %% Generate URNG sequence
    % Mỗi output sample cần A=4 BM samples
    % Mỗi BM sample cần 1 URNG output (32-bit)
    N_urng = N * A;
    
    fprintf('[1/3] Generating %d URNG samples...\n', N_urng);
    [urng_seq, urng_state_log] = taus_urng_fixed(N_urng, seed);
    
    %% Box-Muller pipeline
    fprintf('[2/3] Box-Muller pipeline (%d samples)...\n', N_urng);
    bm_seq = zeros(N_urng, 1, 'int16');
    bm_debug = cell(N_urng, 1);
    
    for i = 1:N_urng
        [bm_seq(i), bm_dbg] = box_muller_fixed(urng_seq(i), fr_table, g_table);
        if nargout > 1 && i <= 100   % chỉ log 100 đầu để tiết kiệm bộ nhớ
            bm_debug{i} = bm_dbg;
        end
    end
    
    %% CLT accumulator
    fprintf('[3/3] CLT accumulation (A=%d) → %d output samples...\n', A, N);
    noise = zeros(N, 1, 'int16');
    clt_debug = cell(min(N, 100), 1);
    
    for i = 1:N
        idx_start = (i-1) * A + 1;
        idx_end   = i * A;
        [noise(i), clt_dbg] = clt_acc_fixed(bm_seq(idx_start:idx_end));
        if nargout > 1 && i <= 100
            clt_debug{i} = clt_dbg;
        end
    end
    
    %% Convert to float for stats
    noise_float = double(noise) / 2^B;
    
    fprintf('\n=== Output statistics ===\n');
    fprintf('  Samples:    %d\n', N);
    fprintf('  Range:      [%d, %d] (Q(2.6) integer)\n', min(noise), max(noise));
    fprintf('  Float:      [%.4f, %.4f]\n', min(noise_float), max(noise_float));
    fprintf('  Mean:       %.6f (target: 0)\n', mean(noise_float));
    fprintf('  Std:        %.6f (target: 1.0)\n', std(noise_float));
    fprintf('  Skewness:   %.6f (target: 0)\n', skewness(noise_float));
    fprintf('  Kurtosis:   %.6f (target: 3)\n', kurtosis(noise_float));
    
    %% Debug output
    if nargout > 1
        debug.urng_seq       = urng_seq;
        debug.urng_state_log = urng_state_log;
        debug.bm_seq         = bm_seq;
        debug.bm_debug       = bm_debug;
        debug.clt_debug      = clt_debug;
        debug.noise_float    = noise_float;
        debug.params.A = A;
        debug.params.B = B;
        debug.params.seed = seed;
        debug.params.N = N;
    end
end
