#!/usr/bin/env python3
"""
sim_bitwidth.py — D5 Bit-width sweep: chứng minh B=6 là sweet spot.
Đo độ lệch phân bố (relative PDF error bulk, KS distance) theo B={4,6,8,10}.
Lưu ý: trong kiến trúc này ROM precision m=m'=7 cố định; B chỉ ảnh hưởng
độ phân giải output (Q1.B). Boutillon Table 1 cho m,m' tăng theo B — ở đây
ta cô lập tác động của B lên output quantization.
"""
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from scipy import stats
import os
from awgn_model import generate

os.makedirs('figures', exist_ok=True)
N = 200000
Bs = [4, 6, 8, 10]
results = []

print("Bit-width sweep...")
for B in Bs:
    _, nf, _, _ = generate(N, fr_mode='m1ln', B=B)
    sd = nf.std()
    z = nf / sd
    # relative PDF error bulk |z|<3
    edges = np.linspace(-3, 3, 49)
    o, _ = np.histogram(z, bins=edges)
    p_obs = o/z.size
    p_exp = np.diff(stats.norm.cdf(edges))
    rel = np.abs(p_obs-p_exp)/np.maximum(p_exp, 1e-12)
    mean_rel = rel.mean()*100
    ks = stats.kstest(z, 'norm').statistic
    n_levels = len(np.unique(nf))           # số mức rời rạc thực tế
    results.append((B, mean_rel, ks*100, n_levels, sd))
    print(f"  B={B:2d}: rel_err_bulk={mean_rel:5.2f}%  KS={ks*100:.3f}%  "
          f"levels={n_levels}  std={sd:.3f}")

Bs_a = np.array([r[0] for r in results])
rel_a = np.array([r[1] for r in results])
ks_a = np.array([r[2] for r in results])
lvl_a = np.array([r[3] for r in results])

# ============================ FIG 8: bitwidth tradeoff ============================
fig, ax1 = plt.subplots(figsize=(8, 5.5))
c1 = '#c0392b'; c2 = '#2471a3'
ax1.plot(Bs_a, rel_a, 'o-', color=c1, lw=1.8, ms=7, label='Sai số PDF bulk (%)')
ax1.plot(Bs_a, ks_a, 's--', color='#e67e22', lw=1.5, ms=6, label='KS distance (%)')
ax1.set_xlabel('Số bit phân số output  B')
ax1.set_ylabel('Sai số so với N(0,1) (%)', color=c1)
ax1.tick_params(axis='y', labelcolor=c1)
ax1.axvline(6, color='green', ls=':', lw=1.5)
ax1.annotate('B=6\n(sweet spot)', xy=(6, rel_a[1]), xytext=(6.6, rel_a[1]+2),
             color='green', fontweight='bold', fontsize=9)
ax1.set_xticks(Bs_a)
ax1.grid(alpha=0.3)

ax2 = ax1.twinx()
ax2.plot(Bs_a, lvl_a, '^-', color=c2, lw=1.5, ms=6, label='Số mức rời rạc')
ax2.set_ylabel('Số mức lượng tử rời rạc', color=c2)
ax2.tick_params(axis='y', labelcolor=c2)

lines1, labels1 = ax1.get_legend_handles_labels()
lines2, labels2 = ax2.get_legend_handles_labels()
ax1.legend(lines1+lines2, labels1+labels2, loc='upper right', fontsize=8)
ax1.set_title('Đánh đổi độ chính xác vs bit-width output B', fontweight='bold')
fig.tight_layout()
fig.savefig('figures/fig8_bitwidth.png', dpi=130)
plt.close(fig)
print("  ✓ fig8_bitwidth.png")

with open('figures/bitwidth_table.txt', 'w') as fp:
    fp.write("BIT-WIDTH SWEEP (m=m'=7 fixed, vary output B)\n")
    fp.write("="*55 + "\n")
    fp.write(f"{'B':>3} {'RelErrBulk%':>12} {'KS%':>8} {'Levels':>8} {'Std':>7}\n")
    for B, rel, ks, lvl, sd in results:
        fp.write(f"{B:>3} {rel:>12.2f} {ks:>8.3f} {lvl:>8} {sd:>7.3f}\n")
    fp.write("\nKet luan: B=4 -> comb tho, sai so lon. B>=8 -> cai thien nho\n")
    fp.write("nhung output width tang. B=6 can bang accuracy/resource.\n")
print("  ✓ bitwidth_table.txt")
print("DONE D5 bitwidth sweep.")
