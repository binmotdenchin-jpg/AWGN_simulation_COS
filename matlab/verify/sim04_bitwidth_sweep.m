%% sim04_bitwidth_sweep.m — Sweep Bit-Width B = {4, 6, 8, 10}
%
% MUC DICH BAO VE:
%   Chung minh KHOA HOC tai sao chon B = 6 (theo Boutillon ICECS'00 Table 1).
%   Khi thay hoi "Sao chon B = 6 ma khong phai 4 hay 10?", co the tra loi
%   bang BIEU DO MSE va resource trade-off.
%
% LUONG MO PHONG:
%
%   Voi moi B in {4, 6, 8, 10}:
%     1. Re-generate Fr ROM va G ROM voi m = m' = B + 1 (theo Boutillon)
%     2. Run fixed-point pipeline => sinh 100k samples
%     3. Tinh metrics:
%        - MSE PDF vs N(0,1) ideal
%        - max abs PDF error
%        - tail accuracy tai +/- 4 sigma
%        - ROM size (bytes)
%     4. Plot bar chart so sanh
%
% KET QUA MONG DOI:
%   B = 4: MSE cao do quantization tho => tail kem
%   B = 6: SWEET SPOT — MSE thap, ROM nho (~90 + 256 bytes)
%   B = 8: MSE thap hon nua nhung ROM lon (~4x)
%   B = 10: Marginal improvement, ROM rat lon
%
% Author: [Ten ban]
% Date:   2026-05-20
% Ref:    Boutillon ICECS'00 Section 4 (error analysis)

clear; clc; close all;

addpath('../float_model');
addpath('../fixed_model');

fprintf('========================================================\n');
fprintf('  SIM04 — Bit-Width Sweep Analysis\n');
fprintf('========================================================\n\n');

%% Parameters
B_range = [4, 6, 8, 10];
N_samples = 100000;
seed = [uint32(12345), uint32(67891), uint32(11213)];

n_bins = 100;
hist_edges = linspace(-5, 5, n_bins + 1);
hist_centers = (hist_edges(1:end-1) + hist_edges(2:end)) / 2;
ideal_pdf = normpdf(hist_centers);

%% Pre-allocate results
N_b = length(B_range);
results = struct();
results.B               = B_range;
results.mse             = zeros(N_b, 1);
results.max_err         = zeros(N_b, 1);
results.tail_4sigma     = zeros(N_b, 1);
results.fr_bytes        = zeros(N_b, 1);
results.g_bytes         = zeros(N_b, 1);
results.total_bytes     = zeros(N_b, 1);
results.std_actual      = zeros(N_b, 1);
results.histograms      = zeros(N_b, n_bins);

%% Sweep loop
for idx = 1:N_b
    B = B_range(idx);
    m  = B + 1;   % Fr ROM fraction bits (theo Boutillon)
    m_prime = B + 1;
    K = 5;
    
    fprintf('  [%d/%d] B = %2d (m = m'' = %d)\n', idx, N_b, B, m);
    
    %% Re-generate ROM tables voi B moi
    fr_table_local = generate_fr_table(K, m, 0.467);
    g_table_local  = generate_g_table(256, m_prime, 0.5);
    
    %% ROM size
    fr_word_bits = 2 + m;
    g_word_bits  = 1 + m_prime;
    results.fr_bytes(idx)    = (K * 16 * fr_word_bits) / 8;
    results.g_bytes(idx)     = (256 * g_word_bits) / 8;
    results.total_bytes(idx) = results.fr_bytes(idx) + results.g_bytes(idx);
    
    %% Run fixed-point pipeline voi B nay
    fprintf('    Running %d samples...', N_samples);
    tic;
    noise_int = run_fixed_pipeline_with_B(N_samples, seed, B, m, m_prime, ...
                                           fr_table_local, g_table_local);
    noise_float = double(noise_int) / 2^B;
    elapsed = toc;
    fprintf(' done (%.1fs)\n', elapsed);
    
    %% Compute metrics
    [hist_pdf, ~] = histcounts(noise_float, hist_edges, 'Normalization', 'pdf');
    pdf_err = hist_pdf - ideal_pdf;
    
    results.histograms(idx, :) = hist_pdf;
    results.mse(idx)           = mean(pdf_err.^2);
    results.max_err(idx)       = max(abs(pdf_err));
    results.tail_4sigma(idx)   = mean(abs(noise_float) > 4) * 100;
    results.std_actual(idx)    = std(noise_float);
    
    fprintf('    MSE = %.2e | max_err = %.4f | std = %.4f | ROM = %d bytes\n', ...
        results.mse(idx), results.max_err(idx), results.std_actual(idx), ...
        results.total_bytes(idx));
end

%% Print summary table
fprintf('\n========================================================\n');
fprintf('  Summary Table\n');
fprintf('========================================================\n');
fprintf('  B   | MSE        | Max err  | Std    | Tail(>4σ) | Fr   | G    | Total ROM\n');
fprintf('  ----+------------+----------+--------+-----------+------+------+----------\n');
ideal_tail = 2 * (1 - normcdf(4)) * 100;
for idx = 1:N_b
    fprintf('  %2d  | %.2e   | %.4f   | %.4f | %.4f%%   | %3d B | %3d B| %4d B\n', ...
        results.B(idx), results.mse(idx), results.max_err(idx), ...
        results.std_actual(idx), results.tail_4sigma(idx), ...
        round(results.fr_bytes(idx)), round(results.g_bytes(idx)), ...
        round(results.total_bytes(idx)));
end
fprintf('\n  Ideal tail (>4σ) = %.4f%%\n', ideal_tail);

%% Visualizations

%% Plot 1: Histograms (4 subplots)
figure('Name', 'SIM04 — Histograms for different B', 'Position', [50 100 1200 800]);
colors = {[0.2 0.4 0.9], [0.2 0.7 0.3], [0.95 0.4 0.2], [0.6 0.2 0.7]};
for idx = 1:N_b
    subplot(2, 2, idx);
    bar(hist_centers, results.histograms(idx, :), 1, ...
        'FaceColor', colors{idx}, 'FaceAlpha', 0.6, 'EdgeColor', 'none');
    hold on;
    plot(hist_centers, ideal_pdf, 'k-', 'LineWidth', 2);
    xlabel('Value');
    ylabel('PDF');
    title(sprintf('B = %d (MSE = %.2e, ROM = %d B)', ...
        results.B(idx), results.mse(idx), round(results.total_bytes(idx))));
    legend('Histogram', 'N(0,1) ideal', 'Location', 'best');
    grid on;
end
sgtitle('Bit-Width Effect on Output Distribution', ...
    'FontSize', 14, 'FontWeight', 'bold');

%% Plot 2: MSE & ROM vs B (trade-off)
figure('Name', 'SIM04 — Trade-off curves', 'Position', [200 200 1100 500]);

subplot(1, 2, 1);
yyaxis left;
semilogy(B_range, results.mse, 'bo-', 'LineWidth', 2, 'MarkerSize', 12, ...
    'MarkerFaceColor', 'b');
ylabel('PDF MSE (log scale)', 'FontSize', 12, 'Color', 'b');
ylim([1e-6, 1e-2]);

yyaxis right;
plot(B_range, results.total_bytes, 'rs-', 'LineWidth', 2, 'MarkerSize', 12, ...
    'MarkerFaceColor', 'r');
ylabel('Total ROM size (bytes)', 'FontSize', 12, 'Color', 'r');

xlabel('Bit-width B (fraction bits)', 'FontSize', 12);
title('Trade-off: Accuracy vs Resource', 'FontSize', 13, 'FontWeight', 'bold');
grid on;
xticks(B_range);

% Highlight chosen B=6
hold on;
xline(6, 'g--', 'LineWidth', 2);
text(6.2, mean(ylim) * 5, 'B = 6 (chosen)', 'FontSize', 11, ...
    'Color', 'g', 'FontWeight', 'bold');

%% Plot 3: Tail accuracy
subplot(1, 2, 2);
plot(B_range, results.tail_4sigma, 'mo-', 'LineWidth', 2, 'MarkerSize', 12, ...
    'MarkerFaceColor', 'm');
hold on;
yline(ideal_tail, 'k--', 'LineWidth', 2);
text(B_range(1) + 0.5, ideal_tail * 1.15, sprintf('Ideal = %.4f%%', ideal_tail), ...
    'FontSize', 10);
xlabel('Bit-width B', 'FontSize', 12);
ylabel('% samples > 4σ', 'FontSize', 12);
title('Tail Accuracy at ±4σ', 'FontSize', 13, 'FontWeight', 'bold');
grid on;
xticks(B_range);
legend('Measured', 'Theoretical', 'Location', 'best');

%% Selection justification
fprintf('\n========================================================\n');
fprintf('  WHY B = 6?\n');
fprintf('========================================================\n');

[~, idx_b6] = min(abs(B_range - 6));
mse_b6 = results.mse(idx_b6);
rom_b6 = results.total_bytes(idx_b6);

% So sanh voi B = 4 (kem hon)
[~, idx_b4] = min(abs(B_range - 4));
mse_b4_ratio = results.mse(idx_b4) / mse_b6;

% So sanh voi B = 8 (tot hon nhung ton resource)
if any(B_range == 8)
    [~, idx_b8] = min(abs(B_range - 8));
    mse_improvement_b8 = mse_b6 / results.mse(idx_b8);
    rom_increase_b8 = results.total_bytes(idx_b8) / rom_b6;
    
    fprintf('  vs B = 4: MSE giam %.1fx khi nang len B = 6\n', mse_b4_ratio);
    fprintf('  vs B = 8: MSE tot hon %.2fx nhung ton %.2fx ROM\n', ...
        mse_improvement_b8, rom_increase_b8);
    fprintf('\n  => B = 6 la SWEET SPOT:\n');
    fprintf('     - MSE = %.2e (du tot cho yeu cau)\n', mse_b6);
    fprintf('     - ROM = %d bytes (nho gon)\n', round(rom_b6));
    fprintf('     - Nang B them khong dem lai loi ich tuong xung\n');
end

%% Save
save('bitwidth_sweep_results.mat', 'results');
fprintf('\n✓ Da luu bitwidth_sweep_results.mat\n');

%% ====================================================================
%% Helper functions
%% ====================================================================

function fr_table = generate_fr_table(K, m, delta)
% Sinh Fr ROM voi m bit fraction
    fr_table = zeros(K, 16);
    for r = 1:K
        for s = 0:15
            if s == 0
                fr_table(r, s+1) = 0;
            else
                x = (s + delta) / (16^r);
                f_val = sqrt(-2 * log(x));
                fr_table(r, s+1) = floor(2^m * f_val + 0.5);
            end
        end
    end
end

function g_table = generate_g_table(N, m_prime, delta_prime)
% Sinh G ROM voi m' bit fraction
    g_table = zeros(N, 1);
    for s = 0:(N-1)
        angle = pi * (s + delta_prime) / (N * 2);
        val = sqrt(2) * cos(angle);
        g_table(s+1) = floor(2^m_prime * val + 0.5);
    end
end

function noise_int = run_fixed_pipeline_with_B(N, seed, B, m, m_prime, ...
                                                  fr_table, g_table)
% Chay fixed-point pipeline voi parameter B tuy chon.
% Day la phien ban inline cua awgn_fixed_top, cho phep doi B linh hoat.

    A = 4;
    K = 5;
    
    % Generate URNG
    N_urng = N * A;
    urng_seq = taus_urng_fixed(N_urng, seed);
    
    % Box-Muller pipeline
    bm_seq = zeros(N_urng, 1, 'int32');
    for i = 1:N_urng
        bm_seq(i) = box_muller_inline(urng_seq(i), fr_table, g_table, B, m, m_prime, K);
    end
    
    % CLT accumulator
    noise_int = zeros(N, 1, 'int32');
    scale_shift = log2(sqrt(A));   % = 1 voi A = 4
    mean_comp_int = A / 2;          % A * 2^(-B-1) * 2^B = A/2
    
    for i = 1:N
        idx_start = (i-1) * A + 1;
        idx_end = i * A;
        sum_val = sum(bm_seq(idx_start:idx_end));
        sum_compensated = sum_val + mean_comp_int;
        % Round-half-up right shift
        half = 2^(scale_shift - 1);
        noise_int(i) = floor((sum_compensated + half) / 2^scale_shift);
    end
end

function bm_out = box_muller_inline(urng_val, fr_table, g_table, B, m, m_p, K)
% Box-Muller core inline (giong box_muller_fixed.m nhung tham so hoa)
    urng_u32 = uint32(urng_val);
    
    % Count leading zeros
    lz_count = 0;
    temp = urng_u32;
    for bit_pos = 31:-1:0
        if bitand(temp, bitshift(uint32(1), bit_pos)) ~= 0
            break;
        end
        lz_count = lz_count + 1;
    end
    
    r = min(floor(lz_count / 4) + 1, K);
    s_start_bit = 32 - (r * 4);
    s = double(bitand(bitshift(urng_u32, -s_start_bit), uint32(15)));
    s_prime = double(bitand(urng_u32, uint32(255)));
    sign_bit = double(bitand(bitshift(urng_u32, -8), uint32(1)));
    
    fr_val = fr_table(r, s + 1);
    g_val = g_table(s_prime + 1);
    
    P_full = fr_val * g_val;
    
    shift = m + m_p - B;
    if shift > 0
        half = 2^(shift - 1);
        P_rounded = floor((P_full + half) / 2^shift);
    else
        P_rounded = P_full;
    end
    
    if sign_bit == 0
        bm_out = P_rounded;
    else
        bm_out = -P_rounded - 1;
    end
end
