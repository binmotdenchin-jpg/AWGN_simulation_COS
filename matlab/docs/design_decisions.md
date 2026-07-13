# Design Decisions — MATLAB Fixed-Point Model

> File này giải thích **TẠI SAO** mỗi parameter được chọn như vậy.
> Khi thầy hỏi "tại sao B=6?", "tại sao round-half-up?", "tại sao A=4?" — câu trả lời ở đây.

---

## 1. Tại sao chọn B = 6 (fraction bits sau dấu phẩy)?

### Trích từ Boutillon ICECS'00 Table 1:
| B | K | m | δ | m' | δ' |
|---|---|---|---|---|---|
| 6 | 5 | 7 | 0.467 | 7 | 0.5 |

### Lý do kỹ thuật:

**B = 6 là sweet spot giữa accuracy và resource:**

- **B nhỏ (4)**: Quantization error lớn → noise distribution có "stair-stepping", χ² test fail.
- **B lớn (8-10)**: ROM size tăng theo cấp số nhân, multiplier rộng hơn → DSP usage tăng, không cần thiết.
- **B = 6**: Đủ để đạt error < 0.1% relative trong ±4σ (yêu cầu của paper).

### Trade-off:
```
B = 6 → output có 2^6 = 64 mức rời rạc trong khoảng (-3σ, +3σ)
      → đủ smooth khi histogram với 100 bins trên 10^5 samples
```

### Câu trả lời nếu thầy hỏi:
> "B = 6 được chọn theo Boutillon ICECS'00, đảm bảo error < 0.1% trong dải ±4σ.
> Nếu cần tail dài hơn (như Lee 2006 cho BER 10⁻¹²), phải tăng B lên 10+
> nhưng đồ án này target BER 10⁻⁶ nên B=6 là đủ."

---

## 2. Tại sao A = 4 (CLT accumulation)?

### CLT Theory recap:
Nếu X₁, X₂, ..., Xₙ là i.i.d. với mean μ, variance σ²:
```
Y = X₁ + X₂ + ... + Xₙ  →  Y ~ N(nμ, nσ²)  khi n → ∞
```

**Quan trọng**: CLT làm "smooth" lỗi quantization của từng sample BM₁ → BM_A gần Gaussian hơn.

### Boutillon eq.(9), (10):
```
mean(BM_A,B) = -A · 2^(-B-1)
std(BM_A,B)  = √A
```

Với A=4: std = 2 → chỉ cần right-shift 1 bit để normalize về N(0,1).
**Lý do quan trọng**: Right-shift là "free" trong hardware (chỉ là wire renaming).

### Tại sao không A = 2, 8, 16?

| A | std | Normalization | Throughput |
|---|---|---|---|
| 1 | 1 | none (nhưng BM₁ chưa đủ Gaussian) | 2 samples/cycle |
| 2 | √2 | nhân/chia phức tạp | 1 sample/cycle |
| **4** | **2 = 2¹** | **right-shift 1 bit (free)** | **0.5 sample/cycle** |
| 8 | √8 = 2√2 | shift + multiply | 0.25 sample/cycle |
| 16 | 4 = 2² | right-shift 2 bit (free) | 0.125 sample/cycle |

A = 4 là **tối ưu nhất**: normalization free + throughput đủ cao (vẫn 10+ MHz nếu clock 50 MHz).

### Câu trả lời nếu thầy hỏi:
> "A = 4 vì 3 lý do: (1) đủ để CLT smooth out quantization error của BM₁,
> (2) std = 2 = 2¹ nên right-shift 1 bit là normalize free trong hardware,
> (3) throughput vẫn đạt mục tiêu > 10 MHz."

---

## 3. Tại sao chọn round-half-up thay vì round-to-nearest-even?

### Các rounding modes phổ biến:

| Mode | Ví dụ 2.5 → ? | Ưu | Nhược |
|---|---|---|---|
| Round-half-up | 3 | Đơn giản, hardware-friendly | Bias +0.5 LSB |
| Round-half-even (banker's) | 2 | Unbiased | Phức tạp hơn |
| Round-toward-zero (truncate) | 2 | Đơn giản nhất | Bias mạnh về 0 |
| MATLAB `round()` | 3 (Inf) / 2 (NaN convention) | — | Tùy version |

### Lý do chọn round-half-up:

1. **Verilog mặc định không có round-half-even** — phải implement extra logic
2. **Boutillon paper không specify** rounding mode → có thể chọn tự do
3. **Bias +0.5 LSB** ở phép quantize có thể được bù bằng CLT (mean compensation `−A·2^(-B-1)`)
4. **MATLAB và Verilog đều dễ implement** → đảm bảo bit-accurate match

### Implement trong MATLAB:
```matlab
function y = round_half_up(x)
    y = floor(x + 0.5);
end
```

### Implement trong Verilog:
```verilog
// x là signed Q(N.M), muốn round về Q(N.K) với K < M
// Cộng 2^(M-K-1) rồi shift phải (M-K) bits
wire signed [W-1:0] x_rounded;
assign x_rounded = (x + (1 << (M-K-1))) >>> (M-K);
```

### Câu trả lời nếu thầy hỏi:
> "Round-half-up vì 3 lý do: đơn giản trong Verilog (chỉ +0.5 LSB rồi truncate),
> bias được CLT compensate, và đảm bảo MATLAB-RTL match chính xác (cùng 1 phép toán)."

---

## 4. Tại sao seed phải > mask complement?

Từ L'Ecuyer 1996, mỗi component Tausworthe có constraint:
- s1 > 1   (vì mask 0xFFFFFFFE = ~1)
- s2 > 7   (vì mask 0xFFFFFFF8 = ~7)
- s3 > 15  (vì mask 0xFFFFFFF0 = ~15)

### Lý do:
Mask `0xFFFFFFFE` xóa bit thấp nhất → nếu seed có dạng `0x0000000X` với X ≤ 1, sau khi mask sẽ thành 0. State = 0 là **degenerate state** (LFSR sẽ stuck ở 0 mãi).

### Cách chọn seed tốt:
```matlab
% TỐT: số lớn, đảm bảo bit cao có 1
seed = [uint32(12345), uint32(67891), uint32(11213)];   % primes

% TỆ: số nhỏ
seed = [uint32(1), uint32(2), uint32(3)];   % vi phạm constraint
```

### Câu trả lời nếu thầy hỏi:
> "Mỗi component Tausworthe có một mask xóa bit thấp. Nếu seed quá nhỏ,
> sau khi mask sẽ thành 0 và LFSR bị stuck. Constraint của L'Ecuyer
> đảm bảo s1>1, s2>7, s3>15 để tránh degenerate state."

---

## 5. Tại sao Fr ROM dùng recursive partition (K=5)?

### Vấn đề:
Hàm `f(x) = √(-2·ln(x))` có đặc tính:
- Khi x → 0: f(x) → ∞ (rất dốc)
- Khi x → 1: f(x) → 0 (phẳng)

Nếu chia đều [0,1] thành 16 đoạn, đoạn [0, 1/16] sẽ quantization error rất lớn vì f thay đổi nhiều ở đó.

### Giải pháp Boutillon: Recursive partition (zoom-in vào x=0)
```
Level 1: chia [0,1] thành 16 đoạn → đoạn đầu là [0, 1/16]
Level 2: chia [0, 1/16] thành 16 đoạn → đoạn đầu là [0, 1/256]
Level 3: chia [0, 1/256] thành 16 đoạn → đoạn đầu là [0, 1/4096]
Level 4: chia [0, 1/4096] thành 16 đoạn → đoạn đầu là [0, 1/65536]
Level 5: chia [0, 1/65536] thành 16 đoạn → đoạn đầu là [0, 1/1048576]
```

Mỗi level cần 16 ROM entries × 9 bits = 144 bits = **18 bytes**.
Tổng: K=5 × 18 = **90 bytes** (rất nhỏ!).

### Bonus: tail length
Càng nhiều level (K cao), càng zoom sâu vào x→0 → noise có tail dài hơn.
K=5 → tail ≈ 4σ (đủ cho BER 10⁻⁶).

### Cách identify (r, s) từ URNG output:
URNG sinh 32-bit uniform `rgr`. Đếm leading zeros:
- 0-3 leading zeros → level r=1, s = bits [27:24]
- 4-7 leading zeros → level r=2, s = bits [23:20]
- ...
- 16-19 leading zeros → level r=5, s = bits [11:8]
- 20+ leading zeros → saturate (output max)

### Câu trả lời nếu thầy hỏi:
> "Recursive partition để 'zoom-in' vào vùng x→0 nơi f(x) = √(-2ln(x)) thay đổi mạnh.
> K=5 levels đảm bảo accuracy ở tail đến ±4σ trong khi tổng ROM chỉ 90 bytes."

---

## 6. Tại sao G ROM chỉ 256 entries (8-bit s')?

### Symmetry của cosine:
cos(θ) có chu kỳ 2π và đối xứng:
- `cos(θ) = cos(-θ)` (đối xứng qua trục y)
- `cos(θ) = -cos(π-θ)` (anti-đối xứng qua π/2)

→ Chỉ cần lưu `cos` trên `[0, π/4]` (1/8 chu kỳ), 7/8 còn lại suy ra bằng sign + index manipulation.

### Boutillon đơn giản hóa:
Lưu `√2·cos(π(s'+0.5)/512)` cho s' = 0..255 → 1/4 chu kỳ.
**Tại sao nhân √2?** Để khoảng output là `[-√2, +√2]`, fit vào 1+m'=8 bits có dấu.

### Câu trả lời nếu thầy hỏi:
> "Vì cosine có symmetry, chỉ cần lưu 1/4 chu kỳ = 256 entries.
> Multiplier √2 để output fit vào 8 bits signed, kết hợp với Fr để tạo Box-Muller."

---

## 7. Tại sao bit-accurate co-simulation là quan trọng?

### Vấn đề thực tế:
Khi viết RTL Verilog, có rất nhiều chỗ dễ sai:
- Off-by-one ở pipeline stage
- Truncation vs rounding inconsistency
- Signed vs unsigned conversion
- Reset polarity (active-HIGH vs LOW)
- Endianness của ROM data

### Giải pháp:
**Build MATLAB fixed-point model làm GOLDEN** — implement đúng từng phép tính như RTL sẽ làm:
- Cùng bit-width
- Cùng rounding mode
- Cùng order of operations
- Cùng saturation/overflow handling

Sau đó:
1. Chạy MATLAB → dump output vào file `golden.txt`
2. Chạy RTL testbench → đọc cùng seed, compare output với golden.txt
3. **Sample-by-sample 100% match** = RTL đúng

### Tại sao hơn debug thuần trên waveform?
- Waveform ModelSim chỉ thấy signals, không biết expected value
- Bit-accurate compare phát hiện mismatch ngay từ sample đầu tiên
- Debug nhanh gấp 5-10 lần

### Câu trả lời nếu thầy hỏi:
> "Vì RTL có hàng trăm cơ hội sai sót (rounding, signedness, pipeline...).
> MATLAB fixed-point làm golden cho phép verify từng sample, debug nhanh,
> và đảm bảo RTL output đúng 100% trước khi synthesize."

---

## Tóm tắt — các parameter chính của design

```
PARAMETERS (theo Boutillon ICECS'00 Table 1):
  B  = 6     % fraction bits Box-Muller output
  K  = 5     % Fr ROM partition levels
  m  = 7     % Fr ROM fraction bits
  δ  = 0.467 % Fr offset
  m' = 7     % G ROM fraction bits
  δ' = 0.5   % G offset
  A  = 4     % CLT accumulation factor

URNG (L'Ecuyer 1996):
  3 components: k₁=31, k₂=29, k₃=28
  Period ≈ 2^88

RESOURCES (estimated):
  Fr ROM:  90 bytes
  G ROM:   256 bytes
  Total LUT: ~250
  Total DSP: 1-2
  Fmax target: 50 MHz (conservative)

ACCURACY:
  ±4σ với error < 0.1%
  Đủ cho BER 10^-6
```
