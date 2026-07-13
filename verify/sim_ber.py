#!/usr/bin/env python3
"""
sim_ber.py — D5 BER simulation (BPSK & QPSK) dùng noise fixed-point bit-exact.
So sánh: lý thuyết Q(.) vs randn lý tưởng vs noise fixed-point (RTL golden).
"""
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from scipy.special import erfc
import os, time
from awgn_model import generate

os.makedirs('figures', exist_ok=True)
rng = np.random.default_rng(1)

def qfunc(x):
    return 0.5*erfc(x/np.sqrt(2))

# ---- Generate fixed-point noise pool (normalize to unit variance) ----
N = 1_000_000
print(f"Generating {N} fixed-point noise samples for BER...")
t = time.time()
_, nf, _, _ = generate(N, fr_mode='m1ln')          # std ~ 1
nf = nf / nf.std()                                  # exact unit variance
print(f"  done in {time.time()-t:.1f}s, std={nf.std():.4f}")

EbN0_dB = np.arange(0, 10, 1)
EbN0 = 10**(EbN0_dB/10)

# ============================ BPSK ============================
print("BPSK BER...")
bits = rng.integers(0, 2, N)
sym = 2*bits - 1                                    # {0,1}->{-1,+1}
ber_fixed, ber_ideal, ber_theory = [], [], []
noise_ideal = rng.standard_normal(N)
for ebn0 in EbN0:
    sigma = np.sqrt(1.0/(2*ebn0))                   # Eb=1, N0=1/ebn0, sigma^2=N0/2
    # fixed-point noise
    r = sym + sigma*nf
    ber_fixed.append(np.mean((r > 0).astype(int) != bits))
    # ideal randn
    r2 = sym + sigma*noise_ideal
    ber_ideal.append(np.mean((r2 > 0).astype(int) != bits))
    ber_theory.append(qfunc(np.sqrt(2*ebn0)))
ber_fixed = np.array(ber_fixed); ber_ideal = np.array(ber_ideal); ber_theory = np.array(ber_theory)
for i, d in enumerate(EbN0_dB):
    print(f"  {d}dB: theory={ber_theory[i]:.2e} ideal={ber_ideal[i]:.2e} fixed={ber_fixed[i]:.2e}")

# ============================ QPSK ============================
print("QPSK BER (Gray)...")
Nsym = N//2
bI = rng.integers(0, 2, Nsym); bQ = rng.integers(0, 2, Nsym)
sI = 2*bI - 1; sQ = 2*bQ - 1
nI = nf[0::2][:Nsym]; nQ = nf[1::2][:Nsym]           # independent decimated streams
niI = noise_ideal[0::2][:Nsym]; niQ = noise_ideal[1::2][:Nsym]
ber_q_fixed, ber_q_theory = [], []
for ebn0 in EbN0:
    # QPSK: Es=2Eb, per-dim noise sigma^2 = N0/2 = 1/(2*ebn0) (same as BPSK per dim)
    sigma = np.sqrt(1.0/(2*ebn0))
    rI = sI + sigma*nI; rQ = sQ + sigma*nQ
    errI = (rI > 0).astype(int) != bI
    errQ = (rQ > 0).astype(int) != bQ
    ber_q_fixed.append((errI.sum()+errQ.sum())/(2*Nsym))
    ber_q_theory.append(qfunc(np.sqrt(2*ebn0)))
ber_q_fixed = np.array(ber_q_fixed); ber_q_theory = np.array(ber_q_theory)

# ============================ FIG 6: BPSK BER ============================
fig, ax = plt.subplots(figsize=(7.5, 5.5))
ax.semilogy(EbN0_dB, ber_theory, 'k-', lw=1.8, label='Lý thuyết  Q(√(2·Eb/N0))')
ax.semilogy(EbN0_dB, ber_ideal, 'gs', ms=6, mfc='none', label='randn lý tưởng (MATLAB)')
ax.semilogy(EbN0_dB, ber_fixed, 'ro', ms=5, label='Noise fixed-point (RTL golden)')
ax.set_xlabel('Eb/N0 (dB)')
ax.set_ylabel('Bit Error Rate (BER)')
ax.set_title('BER BPSK — AWGN channel emulation', fontweight='bold')
ax.set_ylim(1e-5, 1)
ax.grid(True, which='both', alpha=0.3)
ax.legend()
fig.tight_layout()
fig.savefig('figures/fig6_ber_bpsk.png', dpi=130)
plt.close(fig)
print("  ✓ fig6_ber_bpsk.png")

# ============================ FIG 7: QPSK BER + constellation ============================
fig, axes = plt.subplots(1, 2, figsize=(13, 5.5))
ax = axes[0]
ax.semilogy(EbN0_dB, ber_q_theory, 'k-', lw=1.8, label='Lý thuyết Q(√(2·Eb/N0))')
ax.semilogy(EbN0_dB, ber_q_fixed, 'ro', ms=5, label='QPSK fixed-point (RTL golden)')
ax.set_xlabel('Eb/N0 (dB)'); ax.set_ylabel('BER')
ax.set_title('BER QPSK (Gray-coded)', fontweight='bold')
ax.set_ylim(1e-5, 1); ax.grid(True, which='both', alpha=0.3); ax.legend()
# constellation at a mid Eb/N0
ax = axes[1]
ebn0 = 10**(6/10); sigma = np.sqrt(1.0/(2*ebn0))
k = 4000
rI = sI[:k] + sigma*nI[:k]; rQ = sQ[:k] + sigma*nQ[:k]
ax.plot(rI, rQ, '.', ms=2, alpha=0.3, color='#3b78c2')
ax.plot([1,-1,1,-1],[1,1,-1,-1], 'rx', ms=12, mew=2, label='Điểm lý tưởng')
ax.axhline(0, color='gray', lw=0.6); ax.axvline(0, color='gray', lw=0.6)
ax.set_xlabel('In-phase (I)'); ax.set_ylabel('Quadrature (Q)')
ax.set_title(f'Chòm sao QPSK @ Eb/N0=6dB (noise fixed-point)', fontweight='bold')
ax.set_aspect('equal'); ax.legend(); ax.grid(alpha=0.3)
fig.tight_layout()
fig.savefig('figures/fig7_ber_qpsk.png', dpi=130)
plt.close(fig)
print("  ✓ fig7_ber_qpsk.png")

# ---- save BER table ----
with open('figures/ber_table.txt', 'w') as fp:
    fp.write("BER RESULTS (fixed-point noise vs theory)\n")
    fp.write("="*60 + "\n")
    fp.write(f"{'Eb/N0(dB)':>9} {'Theory':>12} {'BPSK-fixed':>12} {'QPSK-fixed':>12}\n")
    for i, d in enumerate(EbN0_dB):
        fp.write(f"{d:>9} {ber_theory[i]:>12.3e} {ber_fixed[i]:>12.3e} "
                 f"{ber_q_fixed[i]:>12.3e}\n")
    # accuracy: ratio fixed/theory in the reliable region
    reliable = ber_theory > 5e-5
    ratio = ber_fixed[reliable]/ber_theory[reliable]
    fp.write(f"\nBPSK fixed/theory ratio (BER>5e-5): "
             f"min={ratio.min():.2f} max={ratio.max():.2f} mean={ratio.mean():.2f}\n")
print(f"  ✓ ber_table.txt (BPSK fixed/theory mean ratio="
      f"{(ber_fixed[ber_theory>5e-5]/ber_theory[ber_theory>5e-5]).mean():.2f})")
print("\nDONE D5 BER.")
