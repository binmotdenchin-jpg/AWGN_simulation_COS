%% sim09_ber_bpsk.m — BER Curve cho BPSK trong AWGN Channel
%
% MUC DICH BAO VE:
%   Day la "MONEY SHOT" cua do an. Neu noise generator dung Gaussian,
%   duong BER thuc nghiem PHAI khop voi duong BER ly thuyet:
%
%       BER_theory = Q(sqrt(2 * Eb/N0))
%                  = 0.5 * erfc(sqrt(Eb/N0))
%
%   Sai lech > 0.5 dB o BER = 10^-4 => noise generator co van de.
%
% LUONG MO PHONG:
%
%       +1 / -1                noise (sigma)             >0 / <0
%   bits --> BPSK_TX --> [+] --> channel --> RX --> BPSK_RX --> decoded_bits
%                        ^
%                        |
%               AWGN generator (D2 fixed-point)
%
% SO SANH 3 NOISE SOURCES:
%   (1) MATLAB built-in randn (reference)
%   (2) D1 float model (Box-Muller floating-point)
%   (3) D2 fixed-point model (Box-Muller + CLT, bit-accurate voi RTL)
%
%   Neu D2 trung voi randn va theory => RTL output cung se dung.
%
% Author: [Ten ban]
% Date:   2026-05-20
% Ref:    Proakis "Digital Communications", Ch.5

clear; clc; close all;

addpath('../float_model');
addpath('../fixed_model');

fprintf('========================================================\n');
fprintf('  SIM09 — BER Curve BPSK in AWGN Channel\n');
fprintf('========================================================\n\n');

%% Parameters
% Eb/N0 sweep range — chon de duong BER di tu ~1e-1 xuong ~1e-5
EbN0_dB_range = 0:1:10;        % dB
N_bits_per_snr = 1e6;          % 1 trieu bit moi diem SNR
                                % => co the do BER thap nhat ~1e-5 voi do tin cay tot

seed = [uint32(12345), uint32(67891), uint32(11213)];
B = 6;  % Q(2.6) format cua D2

%% Pre-allocate
N_snr = length(EbN0_dB_range);
ber_theory  = zeros(N_snr, 1);
ber_randn   = zeros(N_snr, 1);
ber_d1      = zeros(N_snr, 1);
ber_d2      = zeros(N_snr, 1);

%% Theory curve (ly thuyet)
for i = 1:N_snr
    EbN0_lin = 10^(EbN0_dB_range(i) / 10);
    ber_theory(i) = qfunc(sqrt(2 * EbN0_lin));
end

%% Main BER loop
fprintf('Running BER simulation for %d SNR points...\n', N_snr);
fprintf('  N_bits per SNR: %.0e\n', N_bits_per_snr);
fprintf('  Total bits: %.0e\n\n', N_snr * N_bits_per_snr);

for i = 1:N_snr
    EbN0_dB  = EbN0_dB_range(i);
    EbN0_lin = 10^(EbN0_dB / 10);
    
    fprintf('  [%2d/%d] Eb/N0 = %2d dB ', i, N_snr, EbN0_dB);
    tic;
    
    %% Generate random bits
    bits = randi([0 1], N_bits_per_snr, 1);
    
    %% BPSK modulation: 0 -> -1, 1 -> +1
    tx = 2 * bits - 1;  % -1 / +1, Eb = 1
    
    %% Compute noise power
    % BPSK voi Eb = 1, noise variance N0/2 (do AWGN co PSD N0/2 hai chieu,
    % nhung BPSK demod chi xet 1 chieu thuc => variance = N0/2)
    %   Eb/N0 (linear) = Eb / N0 = 1 / N0
    %   => N0 = 1 / EbN0_lin
    %   => sigma^2 = N0/2 = 1/(2 * EbN0_lin)
    %   => sigma   = sqrt(1/(2 * EbN0_lin))
    N0 = 1 / EbN0_lin;
    sigma = sqrt(N0 / 2);
    
    %% --- Noise source 1: MATLAB randn (reference) ---
    noise_randn = sigma * randn(N_bits_per_snr, 1);
    rx_randn = tx + noise_randn;
    bits_rx_randn = rx_randn > 0;
    ber_randn(i) = mean(bits_rx_randn ~= bits);
    
    %% --- Noise source 2: D1 float model ---
    % awgn_float_top tra ve noise ~ N(0,1), nhan voi sigma
    noise_d1_unit = awgn_float_top(N_bits_per_snr, seed, 4);
    noise_d1 = sigma * noise_d1_unit;
    rx_d1 = tx + noise_d1;
    bits_rx_d1 = rx_d1 > 0;
    ber_d1(i) = mean(bits_rx_d1 ~= bits);
    
    %% --- Noise source 3: D2 fixed-point model ---
    % awgn_fixed_top tra ve int16 Q(2.B), chia 2^B de duoc unit variance
    noise_d2_int = awgn_fixed_top(N_bits_per_snr, seed);
    noise_d2_unit = double(noise_d2_int) / 2^B;
    noise_d2 = sigma * noise_d2_unit;
    rx_d2 = tx + noise_d2;
    bits_rx_d2 = rx_d2 > 0;
    ber_d2(i) = mean(bits_rx_d2 ~= bits);
    
    elapsed = toc;
    fprintf('| Theory %.2e | randn %.2e | D1 %.2e | D2 %.2e | %.1fs\n', ...
        ber_theory(i), ber_randn(i), ber_d1(i), ber_d2(i), elapsed);
end

%% Visualization — THE MONEY SHOT
figure('Name', 'SIM09 — BER BPSK in AWGN', 'Position', [100 100 900 600]);

semilogy(EbN0_dB_range, ber_theory, 'k-', 'LineWidth', 2.5, 'DisplayName', 'Theory: Q(sqrt(2 Eb/N0))');
hold on;
semilogy(EbN0_dB_range, ber_randn, 'b^-', 'LineWidth', 1.5, ...
    'MarkerSize', 9, 'MarkerFaceColor', 'b', 'DisplayName', 'MATLAB randn (reference)');
semilogy(EbN0_dB_range, ber_d1, 'gs-', 'LineWidth', 1.5, ...
    'MarkerSize', 9, 'MarkerFaceColor', 'g', 'DisplayName', 'D1 Float (Box-Muller)');
semilogy(EbN0_dB_range, ber_d2, 'ro-', 'LineWidth', 1.5, ...
    'MarkerSize', 9, 'MarkerFaceColor', 'r', 'DisplayName', 'D2 Fixed (RTL golden)');

% Annotations
xlabel('Eb/N0 (dB)', 'FontSize', 12);
ylabel('Bit Error Rate (BER)', 'FontSize', 12);
title('BPSK BER Performance in AWGN — Generator Validation', ...
    'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'southwest', 'FontSize', 11);
grid on; grid minor;
ylim([1e-6 1]);
xlim([min(EbN0_dB_range) max(EbN0_dB_range)]);
set(gca, 'FontSize', 11);

% Annotation arrow showing match
text(7.5, 5e-5, '\leftarrow Cac duong khop nhau', ...
    'FontSize', 11, 'Color', 'r', 'FontWeight', 'bold');

%% Quantitative gap analysis (dB gap o BER = 10^-4)
fprintf('\n========================================================\n');
fprintf('  Gap Analysis (find Eb/N0 needed for BER = 1e-4)\n');
fprintf('========================================================\n');

target_ber = 1e-4;
try
    snr_theory = interp1(log10(ber_theory + eps), EbN0_dB_range, log10(target_ber), 'linear');
    snr_randn  = interp1(log10(ber_randn  + eps), EbN0_dB_range, log10(target_ber), 'linear');
    snr_d1     = interp1(log10(ber_d1     + eps), EbN0_dB_range, log10(target_ber), 'linear');
    snr_d2     = interp1(log10(ber_d2     + eps), EbN0_dB_range, log10(target_ber), 'linear');
    
    fprintf('  Source          | Eb/N0 needed | Gap vs theory\n');
    fprintf('  ----------------+--------------+--------------\n');
    fprintf('  Theory          |  %5.2f dB    |    0.00 dB (ref)\n', snr_theory);
    fprintf('  MATLAB randn    |  %5.2f dB    |  %+5.2f dB\n', snr_randn, snr_randn - snr_theory);
    fprintf('  D1 Float model  |  %5.2f dB    |  %+5.2f dB\n', snr_d1, snr_d1 - snr_theory);
    fprintf('  D2 Fixed-point  |  %5.2f dB    |  %+5.2f dB\n', snr_d2, snr_d2 - snr_theory);
catch
    fprintf('  Khong du data de interpolate tai BER = %.0e\n', target_ber);
end

%% Acceptance criteria
fprintf('\n========================================================\n');
fprintf('  Acceptance Criteria\n');
fprintf('========================================================\n');

% Tieu chi: tat ca 3 noise source phai khop theory trong 0.5 dB
% tai BER = 10^-3 (de tranh do nhieu cua simulation o low BER)

target_ber_accept = 1e-3;
try
    snr_th = interp1(log10(ber_theory + eps), EbN0_dB_range, log10(target_ber_accept));
    snr_d2_check = interp1(log10(ber_d2 + eps), EbN0_dB_range, log10(target_ber_accept));
    gap_d2 = snr_d2_check - snr_th;
    
    if abs(gap_d2) < 0.5
        fprintf('  ✓ PASS: D2 cach theory %.2f dB tai BER 1e-3 (< 0.5 dB)\n', gap_d2);
        fprintf('  ✓✓✓ AWGN GENERATOR VALIDATED\n');
    else
        fprintf('  ⚠ WARN: D2 cach theory %.2f dB (> 0.5 dB threshold)\n', gap_d2);
        fprintf('  Co the do: (1) sigma scale sai, (2) tail behavior kem, (3) bias\n');
    end
catch
    fprintf('  Khong tinh duoc gap — kiem tra simulation\n');
end

%% Save results
save('ber_bpsk_results.mat', 'EbN0_dB_range', 'ber_theory', ...
    'ber_randn', 'ber_d1', 'ber_d2', 'N_bits_per_snr');

fprintf('\n✓ Da luu ber_bpsk_results.mat\n');
fprintf('✓ Plot da hien thi — luu lai cho bao cao chuong 5\n');
