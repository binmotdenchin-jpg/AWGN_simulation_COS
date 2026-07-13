#!/usr/bin/env python3
"""
gen_golden.py — Tái hiện CHÍNH XÁC golden MATLAB fixed-point.
Sinh: fr_table.txt (FR_W=9), g_table.txt (G_W=9), golden_urng/bm/clt.txt
Dùng để verify RTL bit-by-bit.
Mọi phép toán khớp: taus_urng_fixed.m, box_muller_fixed.m, clt_acc_fixed.m,
                    fr_rom_gen.m, g_rom_gen.m
"""
import math, sys, os

MASK32 = 0xFFFFFFFF

# ---------------- Tausworthe URNG (taus_urng_fixed.m) ----------------
def taus_step(s1, s2, s3):
    M1, M2, M3 = 0xFFFFFFFE, 0xFFFFFFF8, 0xFFFFFFF0
    b = (((s1 << 13) & MASK32) ^ s1) >> 19
    s1 = (((s1 & M1) << 12) & MASK32) ^ b
    b = (((s2 << 2) & MASK32) ^ s2) >> 25
    s2 = (((s2 & M2) << 4) & MASK32) ^ b
    b = (((s3 << 3) & MASK32) ^ s3) >> 11
    s3 = (((s3 & M3) << 17) & MASK32) ^ b
    s1 &= MASK32; s2 &= MASK32; s3 &= MASK32
    out = (s1 ^ s2 ^ s3) & MASK32
    return s1, s2, s3, out

def urng_seq(N, seed):
    s1, s2, s3 = seed
    out = []
    for _ in range(N):
        s1, s2, s3, o = taus_step(s1, s2, s3)
        out.append(o)
    return out

# ---------------- ROM tables ----------------
def round_half_up(x):
    return math.floor(x + 0.5)

def fr_table_gen():
    K, m, delta = 5, 7, 0.467
    tbl = [[0]*16 for _ in range(K)]
    for r in range(1, K+1):
        for s in range(16):
            if s == 0:
                tbl[r-1][s] = 0
            else:
                x = (s + delta) / (16**r)
                tbl[r-1][s] = round_half_up(2**m * math.sqrt(-math.log(x)))
    return tbl

def g_table_gen():
    mp, dp = 7, 0.5
    return [round_half_up(2**mp * math.sqrt(2) * math.cos(math.pi*(sp+dp)/512))
            for sp in range(256)]

# ---------------- Box-Muller (box_muller_fixed.m) ----------------
def lzc32(x):
    lz = 0
    for i in range(31, -1, -1):
        if (x >> i) & 1:
            break
        lz += 1
    return lz

def box_muller(urng, fr, g, K=5, B=6, m=7, mp=7):
    lz = lzc32(urng)
    r = min(lz//4 + 1, K)          # 1-based
    r_idx = r - 1
    s_start = 32 - r*4
    s = (urng >> s_start) & 0xF
    s_prime = urng & 0xFF
    sign = (urng >> 8) & 1
    fr_val = fr[r_idx][s]
    g_val = g[s_prime]
    P = fr_val * g_val
    shift = m + mp - B             # 8
    P_round = (P + (1 << (shift-1))) >> shift   # floor, matches MATLAB
    bm = P_round if sign == 0 else (-P_round - 1)
    bm = max(min(bm, 2**15 - 1), -2**15)
    return bm

# ---------------- CLT (clt_acc_fixed.m) ----------------
def clt(bm4, A=4, B=6):
    s = sum(bm4)
    mean_comp = A // 2             # = 2
    sc = s + mean_comp
    scaled = (sc + 1) >> 1         # round-half-up shift1
    return max(min(scaled, 2**15-1), -2**15)

# ---------------- Pipeline ----------------
def pipeline(N_out, seed):
    A = 4
    fr = fr_table_gen(); g = g_table_gen()
    u = urng_seq(N_out*A, seed)
    bm = [box_muller(x, fr, g) for x in u]
    noise = [clt(bm[i*A:(i+1)*A]) for i in range(N_out)]
    return u, bm, noise, fr, g

def to_hex(val, bits):
    if val < 0: val += (1 << bits)
    digits = (bits + 3)//4
    return f"{val:0{digits}X}"

if __name__ == "__main__":
    outdir = sys.argv[1] if len(sys.argv) > 1 else "."
    N = int(sys.argv[2]) if len(sys.argv) > 2 else 2000
    seed = (12345, 67891, 11213)
    os.makedirs(outdir, exist_ok=True)
    u, bm, noise, fr, g = pipeline(N, seed)

    # fr_table.txt (FR_W=9 -> 3 hex digits)
    with open(os.path.join(outdir, "fr_table.txt"), "w") as f:
        for r in range(5):
            for s in range(16):
                f.write(to_hex(fr[r][s], 9) + "\n")
    # g_table.txt (G_W=9 -> 3 hex digits, 2's complement)
    with open(os.path.join(outdir, "g_table.txt"), "w") as f:
        for sp in range(256):
            f.write(to_hex(g[sp], 9) + "\n")
    # golden vectors
    with open(os.path.join(outdir, "golden_urng.txt"), "w") as f:
        for x in u: f.write(f"{x:08X}\n")
    with open(os.path.join(outdir, "golden_bm.txt"), "w") as f:
        for x in bm: f.write(to_hex(x, 16) + "\n")
    with open(os.path.join(outdir, "golden_clt.txt"), "w") as f:
        for x in noise: f.write(to_hex(x, 16) + "\n")

    nf = [x/64.0 for x in noise]
    mean = sum(nf)/len(nf)
    var = sum((x-mean)**2 for x in nf)/len(nf)
    print(f"Generated N={N} into {outdir}/")
    print(f"  Fr max={max(max(r) for r in fr)}  G range=[{min(g)},{max(g)}]")
    print(f"  noise mean={mean:.4f} std={math.sqrt(var):.4f}")
