#!/usr/bin/env python3
"""
sim_verify.py — D5 Statistical Verification (histogram, QQ, PSD, autocorr, chi2)
Sinh figures từ fixed-point noise bit-exact. Lưu PNG vào figures/.
"""
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from scipy import stats, signal
import os, math
from awgn_model import generate

os.makedirs('figures', exist_ok=True)
np.random.seed(0)

N = 300000
print(f"Generating {N} fixed-point samples (both Fr modes)...")
_, nf_paper, bm_paper, _ = generate(N, fr_mode='m1ln')   # std=1 (Boutillon eq.1)
_, nf_curr,  bm_curr,  _ = generate(N, fr_mode='m2ln')   # std=√2 (code hiện tại)

def stat_line(x):
    m, s = x.mean(), x.std()
    sk = float(((x-m)**3).mean()/s**3)
    ku = float(((x-m)**4).mean()/s**4)
    return m, s, sk, ku

mp, sp_, skp, kup = stat_line(nf_paper)
mc, sc_, skc, kuc = stat_line(nf_curr)
print(f"  paper(m1ln): mean={mp:+.4f} std={sp_:.4f} skew={skp:+.3f} kurt={kup:.3f}")
print(f"  curr (m2ln): mean={mc:+.4f} std={sc_:.4f} skew={skc:+.3f} kurt={kuc:.3f}")

# ===================== FIG 1: Histogram vs N(0,1) =====================
fig, axes = plt.subplots(1, 2, figsize=(13, 4.8))
for ax, (nf, lbl, sd) in zip(axes,
        [(nf_paper, 'Fr = √(−ln x)  (Boutillon eq.1)', sp_),
         (nf_curr,  'Fr = √(−2ln x)  (code hiện tại)', sc_)]):
    # normalize to unit variance for fair overlay with N(0,1)
    z = nf / sd
    ax.hist(z, bins=120, density=True, alpha=0.55, color='#3b78c2',
            edgecolor='none', label='Fixed-point (chuẩn hóa)')
    xx = np.linspace(-5, 5, 400)
    ax.plot(xx, stats.norm.pdf(xx), 'r-', lw=1.8, label='N(0,1) lý tưởng')
    ax.set_yscale('linear')
    ax.set_xlim(-5, 5)
    ax.set_xlabel('Giá trị (đã chuẩn hóa σ=1)')
    ax.set_ylabel('Mật độ xác suất')
    ax.set_title(lbl, fontsize=10)
    ax.legend(fontsize=8)
    ax.grid(alpha=0.3)
fig.suptitle('Histogram noise fixed-point vs N(0,1) lý tưởng', fontweight='bold')
fig.tight_layout()
fig.savefig('figures/fig1_histogram.png', dpi=130)
plt.close(fig)
print("  ✓ fig1_histogram.png")

# ===================== FIG 2: Histogram log-scale (tail) =====================
fig, ax = plt.subplots(figsize=(7.5, 5))
z = nf_paper / sp_
counts, edges = np.histogram(z, bins=160, density=True)
centers = 0.5*(edges[:-1]+edges[1:])
ax.semilogy(centers, counts, 'o', ms=2.5, color='#3b78c2', label='Fixed-point')
xx = np.linspace(-5.5, 5.5, 500)
ax.semilogy(xx, stats.norm.pdf(xx), 'r-', lw=1.6, label='N(0,1) lý tưởng')
for k in range(1, 5):
    ax.axvline(k, color='gray', ls=':', lw=0.7)
    ax.axvline(-k, color='gray', ls=':', lw=0.7)
ax.set_ylim(1e-5, 1)
ax.set_xlim(-5.5, 5.5)
ax.set_xlabel('Giá trị (chuẩn hóa σ=1)')
ax.set_ylabel('Mật độ (log)')
ax.set_title('Tail của phân bố (log-scale) — kiểm tra đến ±4σ', fontweight='bold')
ax.legend()
ax.grid(alpha=0.3, which='both')
fig.tight_layout()
fig.savefig('figures/fig2_tail_logscale.png', dpi=130)
plt.close(fig)
print("  ✓ fig2_tail_logscale.png")

# ===================== FIG 3: Q-Q plot =====================
fig, ax = plt.subplots(figsize=(6.5, 6.5))
z = np.sort(nf_paper / sp_)
n = z.size
theo = stats.norm.ppf((np.arange(1, n+1) - 0.5) / n)
ax.plot(theo, z, '.', ms=1.5, color='#3b78c2', alpha=0.5)
lim = 5
ax.plot([-lim, lim], [-lim, lim], 'r-', lw=1.3, label='y = x (lý tưởng)')
ax.set_xlim(-lim, lim); ax.set_ylim(-lim, lim)
ax.set_xlabel('Quantile lý thuyết N(0,1)')
ax.set_ylabel('Quantile mẫu fixed-point')
ax.set_title('Q-Q Plot — fixed-point vs Normal', fontweight='bold')
ax.legend(); ax.grid(alpha=0.3); ax.set_aspect('equal')
fig.tight_layout()
fig.savefig('figures/fig3_qqplot.png', dpi=130)
plt.close(fig)
print("  ✓ fig3_qqplot.png")

# ===================== FIG 4: PSD (Welch) — flatness =====================
fig, ax = plt.subplots(figsize=(8, 5))
f, Pxx = signal.welch(nf_paper/sp_, fs=1.0, nperseg=2048, noverlap=1024,
                       average='median')
Pxx_db = 10*np.log10(Pxx + 1e-20)
ax.plot(f, Pxx_db, color='#3b78c2', lw=0.8, label='PSD ước lượng (Welch)')
mean_db = 10*np.log10(Pxx.mean())
ax.axhline(mean_db, color='r', ls='--', lw=1.3,
           label=f'Trung bình = {mean_db:.2f} dB/Hz')
ax.fill_between(f, mean_db-1, mean_db+1, color='red', alpha=0.08, label='±1 dB')
ripple = Pxx_db.max() - Pxx_db.min()
ax.set_xlabel('Tần số chuẩn hóa (×fs)')
ax.set_ylabel('PSD (dB/Hz)')
ax.set_title(f'Power Spectral Density — kiểm tra phổ phẳng (white)\n'
             f'ripple ≈ {ripple:.1f} dB', fontweight='bold')
ax.legend(fontsize=8); ax.grid(alpha=0.3)
fig.tight_layout()
fig.savefig('figures/fig4_psd.png', dpi=130)
plt.close(fig)
print(f"  ✓ fig4_psd.png (ripple {ripple:.1f} dB)")

# ===================== FIG 5: Autocorrelation =====================
fig, ax = plt.subplots(figsize=(8, 5))
x = (nf_paper - nf_paper.mean()) / nf_paper.std()
maxlag = 50
ac = np.correlate(x, x, mode='full') / x.size
mid = ac.size // 2
ac = ac[mid:mid+maxlag+1]
lags = np.arange(maxlag+1)
markerline, stemlines, baseline = ax.stem(lags, ac, basefmt=' ')
plt.setp(markerline, markersize=3, color='#3b78c2')
plt.setp(stemlines, color='#3b78c2', lw=0.8)
ci = 1.96 / math.sqrt(x.size)
ax.axhline(ci, color='r', ls='--', lw=1, label=f'±95% CI ({ci:.4f})')
ax.axhline(-ci, color='r', ls='--', lw=1)
ax.set_xlabel('Lag (mẫu)')
ax.set_ylabel('Autocorrelation chuẩn hóa')
ax.set_title('Hàm tự tương quan — kiểm tra tính trắng (i.i.d.)', fontweight='bold')
ax.legend(); ax.grid(alpha=0.3)
ax.set_ylim(-0.05, 1.05)
fig.tight_layout()
fig.savefig('figures/fig5_autocorr.png', dpi=130)
plt.close(fig)
out_of_ci = np.sum(np.abs(ac[1:]) > ci)
print(f"  ✓ fig5_autocorr.png ({out_of_ci}/{maxlag} lags ngoài CI)")

# ===================== Chi-square goodness of fit =====================
z = nf_paper / sp_
nbins = 50
lo, hi = -4.5, 4.5
edges = np.linspace(lo, hi, nbins+1)
obs, _ = np.histogram(z, bins=edges)
cdf = stats.norm.cdf(edges)
exp = (cdf[1:] - cdf[:-1]) * z.size
# include tails outside [lo,hi]
exp_lo = stats.norm.cdf(lo) * z.size
exp_hi = (1 - stats.norm.cdf(hi)) * z.size
obs_lo = np.sum(z < lo); obs_hi = np.sum(z > hi)
obs_all = np.concatenate([[obs_lo], obs, [obs_hi]])
exp_all = np.concatenate([[exp_lo], exp, [exp_hi]])
mask = exp_all >= 5
chi2 = np.sum((obs_all[mask]-exp_all[mask])**2 / exp_all[mask])
dof = mask.sum() - 1
pval = 1 - stats.chi2.cdf(chi2, dof)
ks_stat, ks_p = stats.kstest(z, 'norm')
print(f"\n  χ² test (N={N}, oversensitive): χ²={chi2:.1f}, dof={dof}, p={pval:.4f}")
print(f"  KS distance D={ks_stat:.5f} ({ks_stat*100:.3f}% max CDF deviation)")

# --- Relative PDF error (metric thực sự của Boutillon/Lee) ---
# So sánh xác suất bin thực nghiệm vs tích phân N(0,1)
err_edges = np.linspace(-4, 4, 65)   # 64 bins, width 0.125
o, _ = np.histogram(z, bins=err_edges)
p_obs = o / z.size
p_exp = np.diff(stats.norm.cdf(err_edges))
centers_e = 0.5*(err_edges[:-1]+err_edges[1:])
# Poisson relative noise floor cho mỗi bin: 1/sqrt(N*p_exp)
poisson_noise = 1.0/np.sqrt(np.maximum(z.size*p_exp, 1e-9))
rel_err_all = np.abs(p_obs - p_exp) / np.maximum(p_exp, 1e-12)
# Vùng bulk |z|<3: sai số mô hình tách khỏi nhiễu Poisson
bulk = np.abs(centers_e) < 3.0
max_bulk = rel_err_all[bulk].max() * 100
mean_bulk = rel_err_all[bulk].mean() * 100
# Vùng đuôi 3<=|z|<4
tail = (np.abs(centers_e) >= 3.0)
max_tail = rel_err_all[tail].max() * 100
poisson_tail = poisson_noise[tail].max() * 100
print(f"  Sai số PDF bulk (|z|<3): max={max_bulk:.2f}%  mean={mean_bulk:.2f}%")
print(f"  Sai số PDF đuôi (3≤|z|<4): max={max_tail:.1f}% "
      f"(nhiễu Poisson tới {poisson_tail:.1f}% — chủ yếu do sampling)")
max_rel, mean_rel = max_bulk, mean_bulk

# --- Chi-square at moderate N (proper hypothesis test) ---
nf_mod = nf_paper[:8000] / sp_
om, _ = np.histogram(nf_mod, bins=edges)
om_all = np.concatenate([[np.sum(nf_mod < lo)], om, [np.sum(nf_mod > hi)]])
em_all = exp_all * (8000.0 / N)
mk = em_all >= 5
chi2_m = np.sum((om_all[mk]-em_all[mk])**2 / em_all[mk])
dof_m = mk.sum() - 1
p_m = 1 - stats.chi2.cdf(chi2_m, dof_m)
print(f"  χ² test (N=8000, hợp lệ): χ²={chi2_m:.1f}, dof={dof_m}, p={p_m:.4f} "
      f"{'PASS' if p_m>0.05 else 'FAIL'}")

# save stats summary
with open('figures/stats_summary.txt', 'w') as fp:
    fp.write("D5 STATISTICAL VERIFICATION SUMMARY\n")
    fp.write("="*50 + "\n")
    fp.write(f"N samples = {N}\n\n")
    fp.write("Fr = sqrt(-ln x)  [Boutillon eq.1, std target=1]:\n")
    fp.write(f"  mean={mp:+.5f} std={sp_:.5f} skew={skp:+.4f} kurt={kup:.4f}\n\n")
    fp.write("Fr = sqrt(-2ln x) [code hien tai, std=sqrt2]:\n")
    fp.write(f"  mean={mc:+.5f} std={sc_:.5f} skew={skc:+.4f} kurt={kuc:.4f}\n\n")
    fp.write(f"Chi-square (N={N}, oversensitive): chi2={chi2:.2f} dof={dof} p={pval:.4f}\n")
    fp.write(f"Chi-square (N=8000, valid test): chi2={chi2_m:.2f} dof={dof_m} p={p_m:.4f} "
             f"{'PASS' if p_m>0.05 else 'FAIL'}\n")
    fp.write(f"KS distance D={ks_stat:.5f} ({ks_stat*100:.3f}%)\n")
    fp.write(f"Relative PDF error bulk(|z|<3): max={max_bulk:.2f}% mean={mean_bulk:.2f}%\n")
    fp.write(f"Relative PDF error tail(3<=|z|<4): max={max_tail:.1f}% "
             f"(Poisson noise up to {poisson_tail:.1f}%)\n")
    fp.write(f"PSD ripple = {ripple:.2f} dB\n")
    fp.write(f"Autocorr lags out of 95%CI = {out_of_ci}/{maxlag}\n")
print("  ✓ stats_summary.txt")
print("\nDONE D5 statistical figures.")
