%% sim10_ber_qpsk.m — BER Curve cho QPSK trong AWGN Channel
%
% MUC DICH:
%   QPSK truyen 2 bit/symbol qua 2 kenh I (in-phase) va Q (quadrature)
%   doc lap. Demod tach rieng tung kenh => BER bang BPSK voi cung Eb/N0.
%
%   TIEU CHI MO RONG:
%     Khac BPSK chi can 1 chuoi noise, QPSK can 2 chuoi noise DOC LAP
%     cho I va Q. Day la bai test tot cho independence cua AWGN generator.
%
%   BER theory cua QPSK trong AWGN:
%       BER = Q(sqrt(2 * Eb/N0))   (giong BPSK!)
%       SER = 1 - (1 - BER)^2      (symbol error rate)
%
% LUONG MO PHONG:
%
%   bit_pairs --> map (Gray code) --> [I, Q]
%                                       |
%                                       v
%                      [I + nI, Q + nQ] (noise I, Q doc lap)
%                                       |
%                                       v
%                          demod (sign of I, sign of Q)
%                                       |
%                                       v
%                          decoded_bit_pairs
%
% GRAY MAPPING:
%   00 -> (-1, -1)    01 -> (-1, +1)
%   11 -> (+1, +1)    10 -> (+1, -1)
%
% Author: [Ten ban]
% Date:   2026-05-20

clear; clc; close all;

addpath('../float_model');
addpath('../fixed_model');

fprintf('========================================================\n');
fprintf('  SIM10 — BER Curve QPSK in AWGN Channel\n');
fprintf('========================================================\n\n');

%% Parameters
EbN0_dB_range = 0:1:10;
N_bits_per_snr = 1e6;          % phai chan (chia het 2 cho QPSK)
                                % => 500k symbols moi diem SNR

seed_I = [uint32(12345),  uint32(67891),  uint32(11213)];   % seed cho kenh I
seed_Q = [uint32(98765),  uint32(43210),  uint32(22222)];   % seed kenh Q (KHAC seed I)
B = 6;

%% Pre-allocate
N_snr = length(EbN0_dB_range);
ber_theory = zeros(N_snr, 1);
ser_theory = zeros(N_snr, 1);
ber_randn  = zeros(N_snr, 1);
ber_d2     = zeros(N_snr, 1);
ser_d2     = zeros(N_snr, 1);

%% Theory
for i = 1:N_snr
    EbN0_lin = 10^(EbN0_dB_range(i) / 10);
    ber_theory(i) = qfunc(sqrt(2 * EbN0_lin));
    ser_theory(i) = 1 - (1 - ber_theory(i))^2;
end

%% Main loop
fprintf('Running QPSK BER simulation for %d SNR points...\n', N_snr);
fprintf('  N_bits per SNR: %.0e (= %d symbols)\n\n', N_bits_per_snr, N_bits_per_snr/2);

for i = 1:N_snr
    EbN0_dB  = EbN0_dB_range(i);
    EbN0_lin = 10^(EbN0_dB / 10);
    
    fprintf('  [%2d/%d] Eb/N0 = %2d dB ', i, N_snr, EbN0_dB);
    tic;
    
    %% Generate random bits + group thanh symbol (2 bits each)
    bits = randi([0 1], N_bits_per_snr, 1);
    bits = reshape(bits, 2, []);   % 2 x N_sym
    N_sym = size(bits, 2);
    
    %% QPSK Gray mapping:
    %   bit_I = bits(1, :), bit_Q = bits(2, :)
    %   I = 2*bit_I - 1 (1 -> +1, 0 -> -1)
    %   Q = 2*bit_Q - 1
    %   Symbol energy = I^2 + Q^2 = 2 => Es = 2, Eb = Es/2 = 1
    bit_I = bits(1, :)';
    bit_Q = bits(2, :)';
    tx_I = 2 * bit_I - 1;
    tx_Q = 2 * bit_Q - 1;
    
    %% Noise (Eb = 1 sau khi normalize)
    %   Eb/N0 = 1 / N0 => N0 = 1/EbN0_lin
    %   Variance per dimension = N0/2 = 1/(2*EbN0_lin)
    N0 = 1 / EbN0_lin;
    sigma = sqrt(N0 / 2);
    
    %% --- Noise source 1: randn (reference) ---
    nI_randn = sigma * randn(N_sym, 1);
    nQ_randn = sigma * randn(N_sym, 1);
    rx_I = tx_I + nI_randn;
    rx_Q = tx_Q + nQ_randn;
    bit_I_rx = rx_I > 0;
    bit_Q_rx = rx_Q > 0;
    bits_rx = reshape([bit_I_rx, bit_Q_rx]', [], 1);
    bits_tx = reshape([bit_I, bit_Q]', [], 1);
    ber_randn(i) = mean(bits_rx ~= bits_tx);
    
    %% --- Noise source 2: D2 fixed-point (I va Q DOC LAP, khac seed) ---
    nI_int = awgn_fixed_top(N_sym, seed_I);
    nQ_int = awgn_fixed_top(N_sym, seed_Q);
    nI_d2 = sigma * double(nI_int) / 2^B;
    nQ_d2 = sigma * double(nQ_int) / 2^B;
    rx_I_d2 = tx_I + nI_d2;
    rx_Q_d2 = tx_Q + nQ_d2;
    bit_I_rx_d2 = rx_I_d2 > 0;
    bit_Q_rx_d2 = rx_Q_d2 > 0;
    bits_rx_d2 = reshape([bit_I_rx_d2, bit_Q_rx_d2]', [], 1);
    ber_d2(i) = mean(bits_rx_d2 ~= bits_tx);
    
    % SER: symbol error neu I or Q sai
    sym_err = (bit_I_rx_d2 ~= bit_I) | (bit_Q_rx_d2 ~= bit_Q);
    ser_d2(i) = mean(sym_err);
    
    elapsed = toc;
    fprintf('| BER th %.2e | randn %.2e | D2 %.2e | SER th %.2e | SER D2 %.2e | %.1fs\n', ...
        ber_theory(i), ber_randn(i), ber_d2(i), ...
        ser_theory(i), ser_d2(i), elapsed);
end

%% Visualization
figure('Name', 'SIM10 — BER/SER QPSK in AWGN', 'Position', [100 100 1100 600]);

%% Subplot 1: BER
subplot(1, 2, 1);
semilogy(EbN0_dB_range, ber_theory, 'k-', 'LineWidth', 2.5, ...
    'DisplayName', 'BER Theory: Q(sqrt(2 Eb/N0))');
hold on;
semilogy(EbN0_dB_range, ber_randn, 'b^-', 'LineWidth', 1.5, ...
    'MarkerSize', 9, 'MarkerFaceColor', 'b', 'DisplayName', 'MATLAB randn');
semilogy(EbN0_dB_range, ber_d2, 'ro-', 'LineWidth', 1.5, ...
    'MarkerSize', 9, 'MarkerFaceColor', 'r', 'DisplayName', 'D2 Fixed-point');

xlabel('Eb/N0 (dB)', 'FontSize', 12);
ylabel('Bit Error Rate', 'FontSize', 12);
title('QPSK — BER', 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'southwest', 'FontSize', 10);
grid on; grid minor;
ylim([1e-6 1]);
set(gca, 'FontSize', 11);

%% Subplot 2: SER
subplot(1, 2, 2);
semilogy(EbN0_dB_range, ser_theory, 'k-', 'LineWidth', 2.5, ...
    'DisplayName', 'SER Theory: 1-(1-Q(sqrt(2 Eb/N0)))^2');
hold on;
semilogy(EbN0_dB_range, ser_d2, 'ms-', 'LineWidth', 1.5, ...
    'MarkerSize', 9, 'MarkerFaceColor', 'm', 'DisplayName', 'D2 Fixed-point');

xlabel('Eb/N0 (dB)', 'FontSize', 12);
ylabel('Symbol Error Rate', 'FontSize', 12);
title('QPSK — SER', 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'southwest', 'FontSize', 10);
grid on; grid minor;
ylim([1e-6 1]);
set(gca, 'FontSize', 11);

sgtitle('QPSK Performance in AWGN — Generator Validation', ...
    'FontSize', 14, 'FontWeight', 'bold');

%% Constellation plot (at one SNR)
figure('Name', 'SIM10 — QPSK Constellation', 'Position', [200 200 700 600]);

EbN0_constellation_dB = 8;   % chon SNR cao de constellation ro
EbN0_lin = 10^(EbN0_constellation_dB / 10);
sigma_c = sqrt(1 / (2 * EbN0_lin));
N_show = 5000;

bits_show = randi([0 1], N_show*2, 1);
bits_show = reshape(bits_show, 2, []);
I_show = 2 * bits_show(1, :)' - 1;
Q_show = 2 * bits_show(2, :)' - 1;

nI_int = awgn_fixed_top(N_show, seed_I);
nQ_int = awgn_fixed_top(N_show, seed_Q);
rx_I_show = I_show + sigma_c * double(nI_int) / 2^B;
rx_Q_show = Q_show + sigma_c * double(nQ_int) / 2^B;

scatter(rx_I_show, rx_Q_show, 5, 'b.');
hold on;
% Ideal constellation points
plot([-1, -1, 1, 1], [-1, 1, -1, 1], 'r+', 'MarkerSize', 20, 'LineWidth', 3);
% Decision boundaries
plot([0 0], ylim, 'k--', 'LineWidth', 1);
plot(xlim, [0 0], 'k--', 'LineWidth', 1);
xlabel('In-phase (I)', 'FontSize', 12);
ylabel('Quadrature (Q)', 'FontSize', 12);
title(sprintf('QPSK Constellation at Eb/N0 = %d dB (D2 noise)', EbN0_constellation_dB), ...
    'FontSize', 13, 'FontWeight', 'bold');
grid on;
axis equal;
xlim([-3 3]); ylim([-3 3]);
set(gca, 'FontSize', 11);

%% Acceptance criteria
fprintf('\n========================================================\n');
fprintf('  Acceptance Criteria\n');
fprintf('========================================================\n');

target_ber = 1e-3;
try
    snr_th = interp1(log10(ber_theory + eps), EbN0_dB_range, log10(target_ber));
    snr_d2 = interp1(log10(ber_d2 + eps), EbN0_dB_range, log10(target_ber));
    gap = snr_d2 - snr_th;
    
    if abs(gap) < 0.5
        fprintf('  ✓ QPSK PASS: D2 cach theory %.2f dB tai BER 1e-3\n', gap);
    else
        fprintf('  ⚠ QPSK WARN: D2 cach theory %.2f dB\n', gap);
    end
    
    % Independence check — neu nhieu I va Q correlated, SER se sai lech BER theo cong thuc
    expected_ser_to_ber_ratio = ser_theory ./ ber_theory;
    actual_ser_to_ber_ratio   = ser_d2 ./ ber_d2;
    avg_ratio_diff = mean(abs(actual_ser_to_ber_ratio - expected_ser_to_ber_ratio) ...
                          ./ expected_ser_to_ber_ratio, 'omitnan');
    
    fprintf('  Independence check (SER/BER ratio):\n');
    fprintf('    Expected ratio: ~2 (low SNR) to ~%.3f (high SNR)\n', expected_ser_to_ber_ratio(end));
    fprintf('    Avg deviation: %.2f%%\n', avg_ratio_diff * 100);
    if avg_ratio_diff < 0.10
        fprintf('  ✓ Noise I va Q INDEPENDENT (deviation < 10%%)\n');
    else
        fprintf('  ⚠ Possible correlation between I and Q noise streams\n');
    end
catch
    fprintf('  Khong du data de phan tich\n');
end

%% Save
save('ber_qpsk_results.mat', 'EbN0_dB_range', 'ber_theory', ...
    'ber_randn', 'ber_d2', 'ser_theory', 'ser_d2', 'N_bits_per_snr');

fprintf('\n✓ Da luu ber_qpsk_results.mat\n');
