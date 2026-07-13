#!/usr/bin/env python3
"""
rtl_cosim_v2.py — Cycle-accurate co-sim of the UPDATED RTL:
  - taus_urng: valid strobe (fixed)
  - lzc32: binary-search implementation (new)
  - bm_core: PIPE=0 and PIPE=1
Checks noise_out stream against golden_clt.txt, and bm stream against
golden_bm.txt, under continuous-en and pausing-en patterns.
"""
import sys

MASK32 = 0xFFFFFFFF

def to_signed(v, bits):
    v &= (1 << bits) - 1
    return v - (1 << bits) if v & (1 << (bits - 1)) else v

def lzc32_new(x):
    """Mirror of the new lzc32.v binary-search logic."""
    if x == 0:
        return 32
    v = x; n = 0
    if (v >> 16) & 0xFFFF == 0: n |= 16; v = (v << 16) & MASK32
    if (v >> 24) & 0xFF   == 0: n |= 8;  v = (v << 8)  & MASK32
    if (v >> 28) & 0xF    == 0: n |= 4;  v = (v << 4)  & MASK32
    if (v >> 30) & 0x3    == 0: n |= 2;  v = (v << 2)  & MASK32
    if (v >> 31) & 0x1    == 0: n |= 1
    return n

class Top:
    """awgn_top with fixed valid + PIPE parameter."""
    def __init__(self, seeds, fr, g, pipe):
        self.SEEDS = seeds
        self.fr = fr
        self.g = g
        self.pipe = pipe
        # taus_urng regs
        self.s1 = self.s2 = self.s3 = 0
        self.rng_out = 0
        self.urng_valid = 0
        # bm_core regs
        self.fr_q = 0; self.g_q = 0; self.sign_q = 0; self.va = 0
        self.bm_out = 0; self.bm_valid = 0
        # clt regs
        self.acc = 0; self.cnt = 0; self.clt_out = 0; self.out_valid = 0

    # --- combinational helpers ---
    def urng_next(self):
        s1, s2, s3 = self.s1, self.s2, self.s3
        M1, M2, M3 = 0xFFFFFFFE, 0xFFFFFFF8, 0xFFFFFFF0
        b1 = ((((s1 << 13) & MASK32) ^ s1) >> 19)
        b2 = ((((s2 << 2)  & MASK32) ^ s2) >> 25)
        b3 = ((((s3 << 3)  & MASK32) ^ s3) >> 11)
        n1 = ((((s1 & M1) << 12) & MASK32) ^ b1) & MASK32
        n2 = ((((s2 & M2) << 4)  & MASK32) ^ b2) & MASK32
        n3 = ((((s3 & M3) << 17) & MASK32) ^ b3) & MASK32
        return n1, n2, n3

    def bm_extract(self, urng):
        K = 5
        lz = lzc32_new(urng)
        r_idx = min(lz >> 2, K - 1)
        s_start = 28 - r_idx * 4
        s = (urng >> s_start) & 0xF
        s_prime = urng & 0xFF
        sign = (urng >> 8) & 1
        return self.fr[r_idx * 16 + s], self.g[s_prime], sign

    @staticmethod
    def bm_arith(fr_val, g_val, sign):
        p = fr_val * g_val
        p_round = (p + 128) >> 8
        bm = p_round if sign == 0 else (-p_round - 1)
        return max(min(bm, 2**15 - 1), -2**15)

    def clock(self, rst_n, en):
        if not rst_n:
            self.s1, self.s2, self.s3 = self.SEEDS
            self.rng_out = 0; self.urng_valid = 0
            self.fr_q = self.g_q = self.sign_q = self.va = 0
            self.bm_out = 0; self.bm_valid = 0
            self.acc = self.cnt = self.clt_out = self.out_valid = 0
            return 0, 0

        # ---- sample pre-edge values (flip-flop semantics) ----
        urng_q, urng_valid_q = self.rng_out, self.urng_valid
        fr_c, g_c, sign_c = self.bm_extract(urng_q)   # comb from registered urng
        frq, gq, signq, va_q = self.fr_q, self.g_q, self.sign_q, self.va
        bm_out_q, bm_valid_q = self.bm_out, self.bm_valid

        # ---- taus_urng ----
        if en:
            n1, n2, n3 = self.urng_next()
            self.s1, self.s2, self.s3 = n1, n2, n3
            self.rng_out = (n1 ^ n2 ^ n3) & MASK32
            self.urng_valid = 1
        else:
            self.urng_valid = 0   # FIX: strobe

        # ---- bm_core (en = urng_valid_q) ----
        bm_en = urng_valid_q
        # stage A regs (always capture)
        self.fr_q, self.g_q, self.sign_q = fr_c, g_c, sign_c
        self.va = bm_en
        if self.pipe == 0:
            if bm_en:
                self.bm_out = self.bm_arith(fr_c, g_c, sign_c)
                self.bm_valid = 1
            else:
                self.bm_valid = 0
        else:
            if va_q:
                self.bm_out = self.bm_arith(frq, gq, signq)
                self.bm_valid = 1
            else:
                self.bm_valid = 0

        # ---- clt_acc (inputs = pre-edge bm regs) ----
        self.out_valid = 0
        if bm_valid_q:
            if self.cnt == 3:
                s = self.acc + bm_out_q + 2
                scaled = (s + 1) >> 1
                self.clt_out = max(min(scaled, 2**15 - 1), -2**15)
                self.out_valid = 1
                self.acc = 0; self.cnt = 0
            else:
                self.acc += bm_out_q
                self.cnt += 1
        return self.out_valid, self.clt_out, bm_valid_q, bm_out_q


def run(pipe, en_pattern, gold_clt, gold_bm, fr, g, label):
    top = Top((12345, 67891, 11213), fr, g, pipe)
    top.clock(0, 0)
    n_out = len(gold_clt)
    idx = err = bidx = berr = 0
    cyc = 0
    while idx < n_out and cyc < n_out * 4 * 3 + 200:
        r = top.clock(1, en_pattern(cyc))
        ov, val, bv, bval = r
        if bv and bidx < len(gold_bm):
            if bval != gold_bm[bidx]:
                berr += 1
            bidx += 1
        if ov:
            if val != gold_clt[idx]:
                err += 1
            idx += 1
        cyc += 1
    ok = (err == 0 and berr == 0 and idx == n_out and bidx == len(gold_bm))
    print(f"[{label}] PIPE={pipe}  CLT checked={idx} err={err} | BM checked={bidx} err={berr} -> {'PASS' if ok else 'FAIL'}")
    return ok


if __name__ == "__main__":
    base = sys.argv[1]
    fr = [int(l, 16) for l in open(f"{base}/fr_table.txt")]
    g = [to_signed(int(l, 16), 9) for l in open(f"{base}/g_table.txt")]
    gold_clt = [to_signed(int(l, 16), 16) for l in open(f"{base}/golden_clt.txt")]
    gold_bm  = [to_signed(int(l, 16), 16) for l in open(f"{base}/golden_bm.txt")]

    cont  = lambda c: 1
    pause = lambda c: 0 if (c % 100) >= 80 else 1
    rng_en = lambda c: (c * 2654435761 >> 13) & 1   # pseudo-random en

    allok = True
    for pipe in (0, 1):
        allok &= run(pipe, cont,  gold_clt, gold_bm, fr, g, "en lien tuc ")
        allok &= run(pipe, pause, gold_clt, gold_bm, fr, g, "en tam dung ")
        allok &= run(pipe, rng_en, gold_clt, gold_bm, fr, g, "en ngau nhien")
    print("\nTONG KET:", "TAT CA PASS ✔" if allok else "CO LOI ✘")
