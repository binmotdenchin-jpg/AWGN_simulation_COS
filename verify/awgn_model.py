#!/usr/bin/env python3
"""
awgn_model.py — Mô hình fixed-point AWGN bit-exact (vectorized numpy).
Khớp 100% MATLAB golden / RTL đã verify. Dùng cho D5 verification & BER.

Hỗ trợ 2 chế độ Fr:
  fr_mode='m2ln'  : Fr = sqrt(-2*ln(x))  -> KHỚP fr_rom_gen.m hiện tại (std=√2)
  fr_mode='m1ln'  : Fr = sqrt(-ln(x))    -> KHỚP Boutillon eq.(1) (std=1)
Mặc định 'm1ln' — khớp RTL/golden hiện tại (đã sửa theo Boutillon eq.1).
"""
import numpy as np
import math

MASK32 = np.uint32(0xFFFFFFFF)

# ---------------- Tausworthe URNG (serial recurrence) ----------------
def urng_array(N, seed=(12345, 67891, 11213)):
    s1, s2, s3 = (int(seed[0]) & 0xFFFFFFFF,
                  int(seed[1]) & 0xFFFFFFFF,
                  int(seed[2]) & 0xFFFFFFFF)
    M1, M2, M3 = 0xFFFFFFFE, 0xFFFFFFF8, 0xFFFFFFF0
    out = np.empty(N, dtype=np.uint32)
    for i in range(N):
        b = (((s1 << 13) & 0xFFFFFFFF) ^ s1) >> 19
        s1 = ((((s1 & M1) << 12) & 0xFFFFFFFF) ^ b) & 0xFFFFFFFF
        b = (((s2 << 2) & 0xFFFFFFFF) ^ s2) >> 25
        s2 = ((((s2 & M2) << 4) & 0xFFFFFFFF) ^ b) & 0xFFFFFFFF
        b = (((s3 << 3) & 0xFFFFFFFF) ^ s3) >> 11
        s3 = ((((s3 & M3) << 17) & 0xFFFFFFFF) ^ b) & 0xFFFFFFFF
        out[i] = (s1 ^ s2 ^ s3) & 0xFFFFFFFF
    return out

# ---------------- ROM tables ----------------
def fr_table(fr_mode='m2ln'):
    K, m, delta = 5, 7, 0.467
    coef = 2.0 if fr_mode == 'm2ln' else 1.0
    tbl = np.zeros((K, 16), dtype=np.int64)
    for r in range(1, K+1):
        for s in range(16):
            if s == 0:
                tbl[r-1, s] = 0
            else:
                x = (s + delta) / (16**r)
                tbl[r-1, s] = math.floor(2**m * math.sqrt(-coef*math.log(x)) + 0.5)
    return tbl.reshape(-1)   # flat: r_idx*16 + s

def g_table():
    mp, dp = 7, 0.5
    g = np.array([math.floor(2**mp*math.sqrt(2)*math.cos(math.pi*(sp+dp)/512)+0.5)
                  for sp in range(256)], dtype=np.int64)
    return g

# ---------------- Vectorized leading-zero count ----------------
def lz_count_vec(u):
    u = u.astype(np.uint32)
    lz = np.full(u.shape, 32, dtype=np.int64)
    found = np.zeros(u.shape, dtype=bool)
    for i in range(31, -1, -1):
        bit = ((u >> np.uint32(i)) & np.uint32(1)) == 1
        newly = bit & (~found)
        lz[newly] = 31 - i
        found |= bit
    return lz

# ---------------- Vectorized Box-Muller ----------------
def box_muller_vec(u, fr_flat, g_arr, K=5, B=6, m=7, mp=7):
    u = u.astype(np.uint32)
    lz = lz_count_vec(u)
    r = np.minimum(lz // 4 + 1, K)                # 1..K
    r_idx = r - 1
    s_start = (32 - r * 4).astype(np.uint32)      # element-wise shift amount
    s = (np.right_shift(u, s_start) & np.uint32(15)).astype(np.int64)
    s_prime = (u & np.uint32(255)).astype(np.int64)
    sign = ((np.right_shift(u, np.uint32(8))) & np.uint32(1)).astype(np.int64)

    fr_val = fr_flat[r_idx * 16 + s]              # gather
    g_val = g_arr[s_prime]                        # gather
    P = fr_val * g_val                            # int64
    shift = m + mp - B                            # 8 for B=6
    P_round = (P + (1 << (shift - 1))) >> shift   # numpy >> on int64 = arith (floor)
    bm = np.where(sign == 0, P_round, -P_round - 1)
    bm = np.clip(bm, -2**15, 2**15 - 1)
    return bm.astype(np.int64)

# ---------------- Vectorized CLT ----------------
def clt_vec(bm, A=4, B=6):
    n = bm.size // A
    bm = bm[:n*A].reshape(n, A)
    s = bm.sum(axis=1)
    mean_comp = A // 2                            # 2
    sc = s + mean_comp
    scaled = (sc + 1) >> 1                        # round-half-up shift1 (arith)
    return np.clip(scaled, -2**15, 2**15 - 1).astype(np.int64)

# ---------------- Full pipeline ----------------
def generate(N_out, seed=(12345, 67891, 11213), fr_mode='m1ln', B=6):
    A = 4
    u = urng_array(N_out * A, seed)
    fr_flat = fr_table(fr_mode)
    g_arr = g_table()
    bm = box_muller_vec(u, fr_flat, g_arr, B=B)
    noise_int = clt_vec(bm, B=B)
    noise_float = noise_int / float(2**B)
    return noise_int, noise_float, bm, u

if __name__ == "__main__":
    import time
    for mode in ('m2ln', 'm1ln'):
        t = time.time()
        ni, nf, bm, u = generate(200000, fr_mode=mode)
        bm_f = bm / 64.0
        print(f"fr_mode={mode}: N={nf.size}  time={time.time()-t:.1f}s")
        print(f"   single-BM std = {bm_f.std():.4f}")
        print(f"   output   mean = {nf.mean():+.4f}  std = {nf.std():.4f}  "
              f"skew={float(((nf-nf.mean())**3).mean()/nf.std()**3):+.3f}  "
              f"kurt={float(((nf-nf.mean())**4).mean()/nf.std()**4):.3f}")
