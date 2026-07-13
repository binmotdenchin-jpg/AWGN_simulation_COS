%% compare_float_vs_fixed.m — So sánh D1 (float) vs D2 (fixed-point)
%
% Mục đích:
%   1. Verify fixed-point model có chất lượng đủ tốt
%   2. Đo MSE giữa float và fixed
%   3. Plot histogram chồng để check phân bố
%   4. Verify tail behavior (đến ±4σ)
%
% Usage:
%   cd matlab/fixed_model/
%   compare_float_vs_fixed
%
% Author: [Tên bạn]
% Date:   2026-05-20

clear; clc; close all;

%% Setup paths
addpath('../float_model');
addpath('../fixed_model');

fprintf('=========================================\n');
fprintf('  Float vs Fixed-Point Comparison (D1 vs D2)\n');
fprintf('=========================================\n\n');

%% Parameters
N    = 100000;   % output samples
seed = [uint32(12345), uint32(67891), uint32(11213)];
B    = 6;

%% Generate float model output
fprintf('--- D1: Floating-point model ---\n');
tic;
[noise_float, dbg_float] = awgn_float_top(N, seed, 4);
t_float = toc;
fprintf('  Time: %.2f s\n\n', t_float);

%% Generate fixed-point model output
fprintf('--- D2: Fixed-point model ---\n');
tic;
[noise_fixed_int, dbg_fixed] = awgn_fixed_top(N, seed);
noise_fixed = double(noise_fixed_int) / 2^B;
t_fixed = toc;
fprintf('  Time: %.2f s\n\n', t_fixed);

%% Compute error metrics
fprintf('--- Comparison Metrics ---\n');

% NOTE: D1 và D2 KHÔNG cho ra cùng sequence vì:
%   - D1 dùng cos/sin/log floating-point
%   - D2 dùng LUT-based approximation
% → Không thể compare sample-by-sample, chỉ compare statistics

stats_float.mean = mean(noise_float);
stats_float.std  = std(noise_float);
stats_float.skew = skewness(noise_float);
stats_float.kurt = kurtosis(noise_float);

stats_fixed.mean = mean(noise_fixed);
stats_fixed.std  = std(noise_fixed);
stats_fixed.skew = skewness(noise_fixed);
stats_fixed.kurt = kurtosis(noise_fixed);

fprintf('  Metric    |   Float    |   Fixed    |   Δ        |  Target\n');
fprintf('  ----------+------------+------------+------------+--------\n');
fprintf('  Mean      | %+.6f  | %+.6f  | %+.6f  |  0\n', ...
        stats_float.mean, stats_fixed.mean, ...
        stats_fixed.mean - stats_float.mean);
fprintf('  Std       | %.6f   | %.6f   | %+.6f  |  1.0\n', ...
        stats_float.std, stats_fixed.std, ...
        stats_fixed.std - stats_float.std);
fprintf('  Skewness  | %+.6f  | %+.6f  | %+.6f  |  0\n', ...
        stats_float.skew, stats_fixed.skew, ...
        stats_fixed.skew - stats_float.skew);
fprintf('  Kurtosis  | %.6f   | %.6f   | %+.6f  |  3.0\n', ...
        stats_float.kurt, stats_fixed.kurt, ...
        stats_fixed.kurt - stats_float.kurt);

%% Histogram-based MSE
n_bins = 100;
edges  = linspace(-5, 5, n_bins + 1);
centers = (edges(1:end-1) + edges(2:end)) / 2;

[hist_float, ~] = histcounts(noise_float, edges, 'Normalization', 'pdf');
[hist_fixed, ~] = histcounts(noise_fixed, edges, 'Normalization', 'pdf');
ideal_pdf = normpdf(centers);

mse_float = mean((hist_float - ideal_pdf).^2);
mse_fixed = mean((hist_fixed - ideal_pdf).^2);
mse_fixed_vs_float = mean((hist_fixed - hist_float).^2);

fprintf('\n  PDF MSE vs N(0,1):\n');
fprintf('    Float : %.2e\n', mse_float);
fprintf('    Fixed : %.2e\n', mse_fixed);
fprintf('  PDF MSE Fixed vs Float: %.2e\n', mse_fixed_vs_float);

%% Tail analysis
fprintf('\n  Tail analysis (% samples > thresh σ):\n');
fprintf('  Thresh |  Ideal   |  Float   |  Fixed\n');
fprintf('  -------+----------+----------+----------\n');
for thresh = [1, 2, 3, 4, 5]
    ideal_tail = 2 * (1 - normcdf(thresh)) * 100;   % two-tailed %
    float_tail = mean(abs(noise_float) > thresh) * 100;
    fixed_tail = mean(abs(noise_fixed) > thresh) * 100;
    fprintf('  %d σ    | %6.3f%% | %6.3f%% | %6.3f%%\n', ...
            thresh, ideal_tail, float_tail, fixed_tail);
end

%% Visualizations
figure('Name', 'Float vs Fixed Comparison', 'Position', [100 100 1200 800]);

% --- Histogram overlay ---
subplot(2,3,1);
histogram(noise_float, edges, 'Normalization', 'pdf', ...
          'FaceColor', 'b', 'FaceAlpha', 0.5);
hold on;
histogram(noise_fixed, edges, 'Normalization', 'pdf', ...
          'FaceColor', 'r', 'FaceAlpha', 0.5);
plot(centers, ideal_pdf, 'k-', 'LineWidth', 2);
xlabel('Value'); ylabel('PDF');
title('Histogram: Float vs Fixed');
legend('D1 Float', 'D2 Fixed', 'N(0,1) ideal', 'Location', 'best');
grid on;

% --- Log-scale histogram (tail visualization) ---
subplot(2,3,2);
semilogy(centers, ideal_pdf, 'k-', 'LineWidth', 2); hold on;
semilogy(centers, hist_float, 'b-', 'LineWidth', 1);
semilogy(centers, hist_fixed, 'r-', 'LineWidth', 1);
xlabel('Value'); ylabel('PDF (log scale)');
title('Tail behavior (log PDF)');
legend('Ideal', 'Float', 'Fixed', 'Location', 'best');
grid on;
ylim([1e-6, 1]);

% --- Q-Q plots ---
subplot(2,3,3);
qqplot(noise_fixed);
title('Q-Q Plot: Fixed vs Normal');
grid on;

% --- Time series first 200 ---
subplot(2,3,4);
plot(1:200, noise_float(1:200), 'b.-', 'MarkerSize', 6); hold on;
plot(1:200, noise_fixed(1:200), 'r.-', 'MarkerSize', 6);
xlabel('Sample index'); ylabel('Value');
title('First 200 samples');
legend('Float', 'Fixed', 'Location', 'best');
grid on;

% --- PSD comparison ---
subplot(2,3,5);
[pxx_f, f] = pwelch(noise_float, hamming(1024), 512, 1024, 1);
[pxx_fx, ~] = pwelch(noise_fixed, hamming(1024), 512, 1024, 1);
plot(f, 10*log10(pxx_f), 'b-'); hold on;
plot(f, 10*log10(pxx_fx), 'r-');
xlabel('Normalized frequency');
ylabel('PSD (dB)');
title('Power Spectral Density');
legend('Float', 'Fixed', 'Location', 'best');
grid on;

% --- Error histogram ---
subplot(2,3,6);
err_pdf = hist_fixed - ideal_pdf;
plot(centers, err_pdf * 100, 'r-', 'LineWidth', 1.5);
xlabel('Value'); ylabel('PDF error (%)');
title(sprintf('Fixed PDF error vs ideal (max abs: %.3f%%)', max(abs(err_pdf))*100));
yline(0, 'k--');
grid on;

sgtitle('Float (D1) vs Fixed-Point (D2) AWGN Generator Comparison');

%% Acceptance criteria
fprintf('\n=========================================\n');
fprintf('  Acceptance Criteria\n');
fprintf('=========================================\n');

criteria = struct();
criteria(1).name = 'Mean ≈ 0 (|mean| < 0.01)';
criteria(1).pass = abs(stats_fixed.mean) < 0.01;
criteria(2).name = 'Std ≈ 1 (|std - 1| < 0.05)';
criteria(2).pass = abs(stats_fixed.std - 1) < 0.05;
criteria(3).name = 'PDF MSE Fixed < 5e-4';
criteria(3).pass = mse_fixed < 5e-4;
criteria(4).name = 'PDF max error < 1%';
criteria(4).pass = max(abs(err_pdf)) < 0.01;

all_pass = true;
for i = 1:length(criteria)
    if criteria(i).pass
        fprintf('  ✓ PASS: %s\n', criteria(i).name);
    else
        fprintf('  ✗ FAIL: %s\n', criteria(i).name);
        all_pass = false;
    end
end

fprintf('\n');
if all_pass
    fprintf('  ✓✓✓ FIXED-POINT MODEL ACCEPTED — Có thể chuyển sang RTL\n');
else
    fprintf('  ⚠ Cần điều chỉnh fixed-point parameters trước khi RTL\n');
end
fprintf('=========================================\n');
