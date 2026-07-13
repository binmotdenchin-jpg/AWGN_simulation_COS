%% test_quantize_utils.m — Unit tests cho quantize_utils
%
% Chạy script này để verify utility functions hoạt động đúng.
% Mọi test phải PASS trước khi dùng trong fixed_model.
%
% Usage:
%   cd matlab/fixed_model/
%   test_quantize_utils
%
% Author: [Tên bạn]
% Date:   2026-05-20

clear; clc;
fprintf('====================================\n');
fprintf('  Quantize Utils — Unit Tests\n');
fprintf('====================================\n\n');

utils = quantize_utils();
pass_count = 0;
fail_count = 0;

%% Test round_half_up
fprintf('--- round_half_up ---\n');
test_eq('round_half_up(2.5)',  utils.round_half_up(2.5),  3);
test_eq('round_half_up(2.4)',  utils.round_half_up(2.4),  2);
test_eq('round_half_up(2.6)',  utils.round_half_up(2.6),  3);
test_eq('round_half_up(-2.5)', utils.round_half_up(-2.5), -2);  % toward +Inf
test_eq('round_half_up(-2.4)', utils.round_half_up(-2.4), -2);
test_eq('round_half_up(-2.6)', utils.round_half_up(-2.6), -3);
test_eq('round_half_up(0)',    utils.round_half_up(0),    0);

%% Test saturate
fprintf('\n--- saturate ---\n');
test_eq('sat(150, 8, true)',   utils.saturate(150, 8, true),   127);
test_eq('sat(-150, 8, true)',  utils.saturate(-150, 8, true),  -128);
test_eq('sat(100, 8, true)',   utils.saturate(100, 8, true),   100);   % within range
test_eq('sat(300, 8, false)',  utils.saturate(300, 8, false),  255);
test_eq('sat(-1, 8, false)',   utils.saturate(-1, 8, false),   0);

%% Test to_signed / from_signed
fprintf('\n--- to_signed / from_signed ---\n');
test_eq('to_signed(255, 8)',   utils.to_signed(255, 8),   -1);
test_eq('to_signed(128, 8)',   utils.to_signed(128, 8),   -128);
test_eq('to_signed(127, 8)',   utils.to_signed(127, 8),   127);
test_eq('to_signed(0, 8)',     utils.to_signed(0, 8),     0);
test_eq('from_signed(-1, 8)',  utils.from_signed(-1, 8),  255);
test_eq('from_signed(-128, 8)',utils.from_signed(-128, 8),128);
test_eq('from_signed(127, 8)', utils.from_signed(127, 8), 127);

%% Test q_format
fprintf('\n--- q_format ---\n');
% Q(2.6) signed: range -4.0 đến +3.984375, resolution 1/64
% 1.5 → 1.5 * 64 = 96
test_eq('q_format(1.5, 2, 6, true)',     utils.q_format(1.5, 2, 6, true),     96);
% -1.5 → -1.5 * 64 = -96
test_eq('q_format(-1.5, 2, 6, true)',    utils.q_format(-1.5, 2, 6, true),    -96);
% Out of range, should saturate
test_eq('q_format(10.0, 2, 6, true)',    utils.q_format(10.0, 2, 6, true),    255);  % max 8+1 = 9 bits
test_eq('q_format(-10.0, 2, 6, true)',   utils.q_format(-10.0, 2, 6, true),   -256);

%% Test binary conversion
fprintf('\n--- binary conversion ---\n');
test_eq('bin2dec_signed(11111111, 8)', utils.bin2dec_signed('11111111', 8), -1);
test_eq_str('dec2bin_signed(-1, 8)', utils.dec2bin_signed(-1, 8), '11111111');
test_eq_str('dec2bin_signed(127, 8)', utils.dec2bin_signed(127, 8), '01111111');

%% Summary
fprintf('\n====================================\n');
fprintf('  Results: %d passed, %d failed\n', pass_count, fail_count);
fprintf('====================================\n');
if fail_count > 0
    error('Some tests failed.');
else
    fprintf('All tests PASSED ✓\n');
end

%% --- Helper functions ---
function test_eq(name, actual, expected)
    if isequal(actual, expected)
        fprintf('  ✓ %-40s = %g\n', name, actual);
        evalin('caller', 'pass_count = pass_count + 1;');
    else
        fprintf('  ✗ %-40s = %g (expected %g)\n', name, actual, expected);
        evalin('caller', 'fail_count = fail_count + 1;');
    end
end

function test_eq_str(name, actual, expected)
    if strcmp(actual, expected)
        fprintf('  ✓ %-40s = ''%s''\n', name, actual);
        evalin('caller', 'pass_count = pass_count + 1;');
    else
        fprintf('  ✗ %-40s = ''%s'' (expected ''%s'')\n', name, actual, expected);
        evalin('caller', 'fail_count = fail_count + 1;');
    end
end
