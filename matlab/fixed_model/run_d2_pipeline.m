%% run_d2_pipeline.m — Master Script chạy toàn bộ D2 (Fixed-Point Model)
%
% Chạy script này để build & verify toàn bộ fixed-point model.
% Thứ tự đúng:
%   1. Test utilities (quantize_utils)
%   2. Generate ROM tables (Fr, G)
%   3. Test URNG (taus_urng_fixed)
%   4. Generate noise samples + statistics
%   5. Compare with float model
%   6. Generate golden vectors for RTL
%
% Usage:
%   cd matlab/fixed_model/
%   run_d2_pipeline
%
% Author: [Tên bạn]
% Date:   2026-05-20

clear; clc; close all;
fprintf('\n╔═══════════════════════════════════════════════╗\n');
fprintf('║      D2 FIXED-POINT MODEL — FULL PIPELINE     ║\n');
fprintf('╚═══════════════════════════════════════════════╝\n\n');

addpath('../float_model');
addpath('../golden_gen');

%% Step 1: Test utilities
fprintf('━━━ Step 1/6: Testing quantize utilities ━━━\n');
try
    test_quantize_utils;
    fprintf('\n✓ Step 1 PASSED\n\n');
catch ME
    fprintf('\n✗ Step 1 FAILED: %s\n', ME.message);
    return;
end

%% Step 2: Generate ROM tables
fprintf('━━━ Step 2/6: Generating Fr and G ROM tables ━━━\n');
[fr_table, fr_info] = fr_rom_gen();
fprintf('\n');
[g_table,  g_info]  = g_rom_gen();
fprintf('\n✓ Step 2 PASSED\n\n');

%% Step 3: Test URNG
fprintf('━━━ Step 3/6: Testing Tausworthe URNG ━━━\n');
try
    test_taus_urng_fixed;
    fprintf('\n✓ Step 3 PASSED\n\n');
catch ME
    fprintf('\n✗ Step 3 FAILED: %s\n', ME.message);
    return;
end

%% Step 4: Run fixed-point pipeline
fprintf('━━━ Step 4/6: Running fixed-point pipeline ━━━\n');
N_test = 50000;
seed = [uint32(12345), uint32(67891), uint32(11213)];
[noise_int, debug] = awgn_fixed_top(N_test, seed);

noise_float = double(noise_int) / 2^6;

% Quick sanity check
if abs(mean(noise_float)) > 0.1
    error('Mean too far from 0: %.4f', mean(noise_float));
end
if abs(std(noise_float) - 1) > 0.2
    error('Std too far from 1: %.4f', std(noise_float));
end
fprintf('\n✓ Step 4 PASSED — Output looks Gaussian\n\n');

%% Step 5: Compare with float model
fprintf('━━━ Step 5/6: Comparing Float vs Fixed ━━━\n');
compare_float_vs_fixed;
fprintf('\n✓ Step 5 DONE — Xem plots để kiểm tra\n\n');

%% Step 6: Generate golden vectors
fprintf('━━━ Step 6/6: Generating golden vectors for RTL ━━━\n');
golden_gen(10000, seed);
fprintf('\n✓ Step 6 PASSED\n\n');

%% Final summary
fprintf('\n╔═══════════════════════════════════════════════╗\n');
fprintf('║          D2 PIPELINE BUILD COMPLETE           ║\n');
fprintf('╚═══════════════════════════════════════════════╝\n\n');
fprintf('Outputs generated:\n');
fprintf('  • fr_table.txt, fr_table.mat\n');
fprintf('  • g_table.txt, g_table.mat\n');
fprintf('  • rtl/tb/golden_*.txt (5 files)\n');
fprintf('  • rtl/tb/golden.mat\n');
fprintf('\nNext step: Implement RTL Verilog (Tuần 5)\n');
fprintf('  Mỗi module RTL sẽ được verify bằng golden vectors này.\n\n');
