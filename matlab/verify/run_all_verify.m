%% run_all_verify.m — Chạy tất cả verification cho D1 (float model)
%
% Script tổng hợp: gọi từng verify script, sinh plots + report.
%
% Usage:
%   cd('awgn_project/matlab/verify');
%   run_all_verify
%
% Author: [Tên bạn]
% Date:   2026-05-20

clear; clc; close all;
addpath('../float_model');

fprintf('====================================================\n');
fprintf('  AWGN Generator — Floating-Point Model Verification\n');
fprintf('====================================================\n\n');

%% Parameters
N_output  = 100000;   % 100k output samples
seed      = [uint32(12345), uint32(67891), uint32(11213)];
A         = 4;        % CLT accumulation factor

%% Generate noise
fprintf('--- Generating noise ---\n');
[noise, debug] = awgn_float_top(N_output, seed, A);
fprintf('\n');

%% ===== SIM01: URNG Quality =====
fprintf('--- SIM01: URNG Uniformity Test ---\n');
figure('Name', 'SIM01: URNG Quality');

subplot(1,2,1);
histogram(debug.u_all, 100, 'Normalization', 'pdf');
hold on; yline(1, 'r--', 'Ideal Uniform', 'LineWidth', 1.5);
xlabel('Value'); ylabel('PDF');
title('URNG Output Distribution');
legend('Histogram', 'Ideal U(0,1)');

subplot(1,2,2);
autocorr(debug.u_all, 'NumLags', 50);
title('URNG Autocorrelation');
sgtitle('SIM01: Tausworthe URNG Quality');

% KS test for uniformity
[h_ks, p_ks] = kstest(debug.u_all, 'CDF', makedist('Uniform'));
fprintf('  KS test (H0: uniform): h=%d, p=%.4f → %s\n\n', ...
        h_ks, p_ks, ternary(h_ks==0, 'PASS ✓', 'FAIL ✗'));

%% ===== SIM02: Box-Muller Histogram =====
fprintf('--- SIM02: Box-Muller Output ---\n');
figure('Name', 'SIM02: Box-Muller');

subplot(1,2,1);
histogram(debug.bm_all, 200, 'Normalization', 'pdf');
hold on;
x_plot = linspace(-5, 5, 1000);
plot(x_plot, normpdf(x_plot), 'r-', 'LineWidth', 2);
xlabel('Value'); ylabel('PDF');
title('BM₁ (before CLT)');
legend('BM output', 'N(0,1) ideal');

subplot(1,2,2);
qqplot(debug.bm_all);
title('Q-Q Plot (BM₁ vs Normal)');
sgtitle('SIM02: Box-Muller Float Output');

%% ===== SIM03: CLT Effect =====
fprintf('--- SIM03: CLT Effect (A=1,2,4,8) ---\n');
figure('Name', 'SIM03: CLT Effect');

A_values = [1, 2, 4, 8];
colors = {'b', 'g', 'r', 'm'};
for idx = 1:length(A_values)
    a = A_values(idx);
    N_needed = N_output * a;
    [u_tmp, ~] = taus_urng(N_needed, seed);
    [bm0, bm1] = box_muller(u_tmp(1:2:end), u_tmp(2:2:end));
    bm_tmp = zeros(N_needed, 1);
    bm_tmp(1:2:end) = bm0; bm_tmp(2:2:end) = bm1;
    y_tmp = clt_acc(bm_tmp(1:N_output*a), a);
    
    subplot(2,2,idx);
    histogram(y_tmp, 200, 'Normalization', 'pdf', ...
              'FaceColor', colors{idx}, 'FaceAlpha', 0.6);
    hold on;
    plot(x_plot, normpdf(x_plot), 'k-', 'LineWidth', 2);
    xlabel('Value'); ylabel('PDF');
    title(sprintf('A = %d (std=%.3f)', a, std(y_tmp)));
    legend(sprintf('A=%d', a), 'N(0,1)');
end
sgtitle('SIM03: Effect of CLT Accumulation');

%% ===== SIM05: PSD Flatness =====
fprintf('--- SIM05: PSD Flatness ---\n');
figure('Name', 'SIM05: PSD');

fs = 1;  % normalized
[pxx, f] = pwelch(noise, hamming(1024), 512, 1024, fs);
plot(f, 10*log10(pxx), 'b-');
xlabel('Normalized Frequency (×π rad/sample)');
ylabel('PSD (dB/Hz)');
title('SIM05: Power Spectral Density (Welch)');
grid on;
% Đánh giá flatness: max-min trong band
psd_db = 10*log10(pxx);
fprintf('  PSD flatness: max=%.2f dB, min=%.2f dB, range=%.2f dB\n\n', ...
        max(psd_db), min(psd_db), max(psd_db)-min(psd_db));

%% ===== SIM06: Autocorrelation =====
fprintf('--- SIM06: Autocorrelation ---\n');
figure('Name', 'SIM06: Autocorrelation');

[acf, lags] = xcorr(noise - mean(noise), 100, 'normalized');
stem(lags, acf, 'b.', 'MarkerSize', 4);
xlabel('Lag'); ylabel('Normalized ACF');
title('SIM06: Autocorrelation Function');
hold on;
yline(1.96/sqrt(N_output), 'r--');
yline(-1.96/sqrt(N_output), 'r--');
legend('ACF', '95% confidence bound');
grid on;

%% ===== SIM07: Chi-squared + KS Test =====
fprintf('--- SIM07: Statistical Tests ---\n');

% Chi-squared test
n_bins = 50;
[counts, edges] = histcounts(noise, n_bins);
expected = N_output * diff(normcdf(edges));
chi2_stat = sum((counts - expected).^2 ./ expected);
chi2_df = n_bins - 1;
chi2_p = 1 - chi2cdf(chi2_stat, chi2_df);
fprintf('  Chi-squared: χ²=%.2f, df=%d, p=%.4f → %s\n', ...
        chi2_stat, chi2_df, chi2_p, ternary(chi2_p > 0.05, 'PASS ✓', 'FAIL ✗'));

% KS test for normality
[h_norm, p_norm] = kstest((noise - mean(noise)) / std(noise));
fprintf('  KS test (H0: normal): h=%d, p=%.4f → %s\n\n', ...
        h_norm, p_norm, ternary(h_norm==0, 'PASS ✓', 'FAIL ✗'));

%% ===== Summary =====
fprintf('====================================================\n');
fprintf('  Summary\n');
fprintf('====================================================\n');
fprintf('  Samples generated:  %d\n', N_output);
fprintf('  Mean:               %.6f  (ideal: 0)\n', mean(noise));
fprintf('  Std:                %.6f  (ideal: 1)\n', std(noise));
fprintf('  Skewness:           %.6f  (ideal: 0)\n', skewness(noise));
fprintf('  Kurtosis:           %.6f  (ideal: 3)\n', kurtosis(noise));
fprintf('  PSD range:          %.2f dB  (ideal: 0)\n', max(psd_db)-min(psd_db));
fprintf('  Chi-squared p:      %.4f\n', chi2_p);
fprintf('  KS test p:          %.4f\n', p_norm);
fprintf('====================================================\n');

%% Helper
function s = ternary(cond, a, b)
    if cond, s = a; else, s = b; end
end
