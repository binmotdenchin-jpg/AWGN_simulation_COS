# GIẢI THÍCH TOÀN BỘ CODE MATLAB — Dùng cho Bảo Vệ Đồ Án

> File này giải thích logic, lý do, và cách hoạt động của TỪNG file MATLAB trong dự án.
> Khi thầy hỏi bất kỳ câu hỏi nào về code → tra cứu ở đây.
> Mỗi mục có: **Mục đích** → **Cách hoạt động** → **Câu hỏi thầy có thể hỏi** → **Câu trả lời**

---

## MỤC LỤC

### PHẦN A: Float Model (D1)
1. taus_urng.m
2. box_muller.m
3. clt_acc.m
4. awgn_float_top.m

### PHẦN B: Fixed-Point Model (D2)
5. quantize_utils.m
6. taus_urng_fixed.m
7. fr_rom_gen.m
8. g_rom_gen.m
9. box_muller_fixed.m
10. clt_acc_fixed.m
11. awgn_fixed_top.m

### PHẦN C: Verification & Testing
12. test_quantize_utils.m
13. test_taus_urng_fixed.m
14. compare_float_vs_fixed.m
15. run_d2_pipeline.m
16. run_all_verify.m

### PHẦN D: Golden Vectors & BER
17. golden_gen.m
18. sim04_bitwidth_sweep.m
19. sim09_ber_bpsk.m
20. sim10_ber_qpsk.m

---

# PHẦN A: FLOAT MODEL (D1)
## Vai trò: Reference behavior — chạy "đúng toán" để so sánh với fixed-point

---

## 1. taus_urng.m — Bộ sinh số ngẫu nhiên đều (URNG)

### Mục đích
Sinh dãy số **phân bố đều** (uniform) trong [0, 1). Đây là "nguyên liệu đầu vào"
cho Box-Muller — nếu URNG kém thì mọi thứ sau đó đều sai.

### Tại sao dùng Tausworthe (L'Ecuyer) thay vì rand() của MATLAB?
- MATLAB `rand()` dùng Mersenne Twister — rất tốt nhưng **không reproduce được trên Verilog**.
- Tausworthe chỉ dùng XOR + shift + AND → **implement trên FPGA chỉ cần ~150 LUTs**.
- Period 2^88 ≈ 10^26 — đủ dài để không lặp lại trong bất kỳ simulation thực tế nào.

### Cách hoạt động (line by line)
3 "component" chạy song song, mỗi component là 1 LFSR (Linear Feedback Shift Register):
```
Component 1 (s1): b = (s1 << 13) XOR s1 → b >>= 19 → s1 = (s1 AND mask) << 12 XOR b
Component 2 (s2): b = (s2 << 2) XOR s2  → b >>= 25 → s2 = (s2 AND mask) << 4  XOR b
Component 3 (s3): b = (s3 << 3) XOR s3  → b >>= 11 → s3 = (s3 AND mask) << 17 XOR b
```
Output = s1 XOR s2 XOR s3 → nhân 2^(-32) để ra [0, 1).

### Mask là gì? Tại sao cần?
Mask xóa vài bit thấp để đảm bảo primitive polynomial hoạt động đúng:
- s1 mask 0xFFFFFFFE: xóa bit 0 → liên quan đến k₁=31
- s2 mask 0xFFFFFFF8: xóa 3 bit thấp → k₂=29
- s3 mask 0xFFFFFFF0: xóa 4 bit thấp → k₃=28

### ❓ Thầy hỏi: "Tại sao seed phải > 1, > 7, > 15?"
> **Trả lời**: Nếu seed ≤ mask complement (ví dụ s1 ≤ 1), sau khi AND mask sẽ thành 0.
> LFSR ở state 0 sẽ stuck mãi ở 0 — degenerate state. Constraint đảm bảo LFSR
> luôn ở state hợp lệ.

### ❓ Thầy hỏi: "Sao không dùng rand() cho đơn giản?"
> **Trả lời**: Mục tiêu là co-simulation MATLAB ↔ Verilog. `rand()` dùng Mersenne
> Twister 19937-bit state — quá phức tạp để implement trên FPGA. Tausworthe chỉ
> cần 96 bits state (3×32) và phép toán cơ bản, rất phù hợp cho hardware.

---

## 2. box_muller.m — Biến đổi Box-Muller (floating-point)

### Mục đích
Biến 2 số uniform u₀, u₁ → 2 số Gaussian N(0,1).

### Công thức toán
```
f  = √(-2·ln(u₀))          ← "radial" component
g₀ = sin(2π·u₁)            ← "angular" component
g₁ = cos(2π·u₁)
x₀ = f · g₀                ← output Gaussian #1
x₁ = f · g₁                ← output Gaussian #2
```

### Trực giác hình học
- u₀ quyết định **khoảng cách từ gốc** (theo phân bố Rayleigh)
- u₁ quyết định **góc** (uniform trên vòng tròn)
- Kết hợp → điểm (x₀, x₁) có phân bố Gaussian 2D trên mặt phẳng

### Guard: `u0(u0 == 0) = eps`
Vì ln(0) = -∞ → cần tránh. Xác suất u₀ = 0 chính xác là 0 trong lý thuyết,
nhưng máy tính dùng số hữu hạn nên cần guard.

### ❓ Thầy hỏi: "Tại sao Box-Muller mà không phải Ziggurat?"
> **Trả lời**: Box-Muller tạo output DETERMINISTIC — mỗi cặp input luôn cho 1 cặp output,
> throughput cố định. Ziggurat dùng rejection sampling → throughput biến thiên, khó
> pipeline trên FPGA. Box-Muller phù hợp hơn cho hardware implementation.

---

## 3. clt_acc.m — Bộ tích lũy CLT (Central Limit Theorem)

### Mục đích
Cộng A = 4 sample Box-Muller lại → 1 output sample. CLT đảm bảo output
gần Gaussian hơn từng sample đơn lẻ (smooth lỗi quantization).

### Toán
```
Y = (X₁ + X₂ + X₃ + X₄) / √4 = (X₁ + X₂ + X₃ + X₄) / 2
```
Nếu Xi ~ N(0,1) thì Y ~ N(0,1) (vì sum/√N giữ nguyên phân bố).

### Tại sao cần CLT khi Box-Muller đã cho N(0,1)?
Trong **float mode** — không cần. Box-Muller floating-point cho N(0,1) rất tốt.
Nhưng trong **fixed-point** (Boutillon method), Fr ROM và G ROM có sai số quantization
→ mỗi BM sample lệch khỏi Gaussian lý tưởng. CLT "trung bình hóa" các lỗi này.

### ❓ Thầy hỏi: "Throughput giảm mấy lần khi dùng CLT?"
> **Trả lời**: Giảm A = 4 lần. Nếu URNG chạy 50 MHz, mỗi BM sample cần 1 cycle,
> thì output rate = 50/4 = 12.5 MHz (vẫn > 10 MHz target).

---

## 4. awgn_float_top.m — Pipeline đầy đủ

### Mục đích
Nối URNG → Box-Muller → CLT thành 1 pipeline hoàn chỉnh. Dùng để:
1. Verify D1 (run_all_verify.m)
2. So sánh với D2 (compare_float_vs_fixed.m)
3. Noise source cho sim09 BER BPSK

### Flow
```
URNG sinh N×A uniform → chia cặp (u0, u1) → BM → interleave x0,x1 → CLT(A=4) → output
```

### ❓ Thầy hỏi: "Tại sao cần N×A uniform mà không phải N?"
> **Trả lời**: Mỗi output sample cần A=4 BM samples (do CLT). Mỗi BM sample cần
> 1 URNG output. Vậy N output cần N×4 URNG outputs. (Trong paper Boutillon,
> mỗi BM call dùng nhiều bit từ 1 URNG output, nhưng ở float model ta dùng
> cặp u0,u1 riêng biệt cho rõ ràng.)

---

# PHẦN B: FIXED-POINT MODEL (D2)
## Vai trò: GOLDEN REFERENCE cho RTL — phải khớp bit-by-bit với Verilog

---

## 5. quantize_utils.m — Công cụ lượng tử hóa

### Mục đích
Tập hợp các hàm quantization dùng CHUNG cho toàn bộ D2.
Đảm bảo MỌI phép round/truncate/saturate đều NHẤT QUÁN.

### Các hàm chính

**round_half_up(x)**:
```
2.5 → 3, 2.4 → 2, -2.5 → -2 (về phía +∞)
Verilog equivalent: y = (x + half) >>> shift
```
Tại sao chọn mode này: đơn giản trong Verilog (chỉ cộng rồi shift),
bias được CLT bù, đảm bảo MATLAB-Verilog match.

**saturate(x, n_bits, signed)**:
Clamp giá trị vào range hợp lệ. Ví dụ 8-bit signed: [-128, 127].
Tránh overflow khi multiply hoặc accumulate.

**to_signed / from_signed**:
Chuyển đổi giữa unsigned bit-pattern và signed value (2's complement).
Giống `$signed()` và `$unsigned()` trong Verilog.

**q_format(x, n_int, n_frac, signed)**:
Chuyển float → fixed-point: nhân 2^n_frac, round, saturate.
Ví dụ: 1.5 → Q(2.6) → 1.5 × 64 = 96 (integer representation).

### ❓ Thầy hỏi: "Q(2.6) format nghĩa là gì?"
> **Trả lời**: 2 bit phần nguyên, 6 bit phần thập phân. Tổng cộng 2+6=8 bits (plus sign bit
> nếu signed = 9 bits). Range: ±(2^2 - 2^(-6)) = ±3.984375. Resolution: 2^(-6) = 0.015625.
> Giá trị float V được lưu dưới dạng integer I = V × 2^6, khi dùng thì chia lại.

---

## 6. taus_urng_fixed.m — URNG bit-exact với Verilog

### Khác biệt với taus_urng.m (float):
| | Float (D1) | Fixed (D2) |
|---|---|---|
| Output | double [0, 1) | uint32 (32-bit raw) |
| Multiply 2^(-32)? | Có | Không |
| Dùng cho | Box-Muller float | Extract bits cho ROM lookup |

### Tại sao output uint32 thay vì double?
Vì Verilog RTL sẽ output 32-bit unsigned. Để bit-exact match, MATLAB cũng phải
giữ nguyên 32-bit integer, KHÔNG convert sang float (tránh sai số floating-point).

### bitshift_left32 / bitshift_right32
MATLAB `bitshift` cho uint32 tự wrap-around nhưng ta viết riêng function
để RÕ RÀNG rằng đây là 32-bit operation — dễ audit khi so với Verilog.

### ❓ Thầy hỏi: "Sao phải viết riêng hàm shift? MATLAB đã có bitshift rồi"
> **Trả lời**: Đúng, MATLAB bitshift cho uint32 hoạt động đúng. Nhưng viết explicit
> function giúp: (1) document rõ ý đồ, (2) dễ audit so với Verilog assign,
> (3) tránh nhầm khi copy-paste sang loại khác (int32, int64...).

---

## 7. fr_rom_gen.m — Sinh bảng Fr ROM

### Công thức Boutillon eq.(4):
```
Fr(s) = round(2^m × √(-2·ln((s + δ) / 16^r)))     khi s > 0
Fr(0) = 0
```

### Giải thích tham số:
- **r = 1..5**: "zoom level". r=1 = nhìn xa (x ∈ [0,1]), r=5 = zoom sát (x ≈ 0)
- **s = 0..15**: vị trí trong mỗi zoom level (4-bit index)
- **m = 7**: precision — lưu 7 bit phần thập phân
- **δ = 0.467**: offset để giảm quantization error tại biên segment

### Tại sao recursive partition?
Hàm f(x) = √(-2·ln(x)) thay đổi RẤT NHANH gần x=0:
```
f(0.5)   = 1.18    (thay đổi chậm)
f(0.01)  = 3.03    (nhanh hơn)
f(0.0001)= 4.29    (rất nhanh)
```
Nếu chia đều [0,1] thành 16 đoạn → đoạn [0, 1/16] sẽ quantize rất thô.
Recursive partition "zoom-in" vào x=0 → accuracy cao hơn ở tail.

### Output: 2 file
- `fr_table.mat`: cho MATLAB fixed-point pipeline đọc
- `fr_table.txt`: cho Verilog `$readmemh` load ROM

### ❓ Thầy hỏi: "Tại sao K=5? K=3 hay K=7 được không?"
> **Trả lời**: K quyết định tail length của noise. K=5 cho tail ≈ ±4σ, đủ cho BER 10^(-6).
> K=3 sẽ tail ngắn → BER curve lệch ở SNR cao. K=7 tốt hơn nhưng ROM tăng gấp đôi
> mà improvement marginal. K=5 là trade-off trong paper Boutillon.

---

## 8. g_rom_gen.m — Sinh bảng G ROM (cosine)

### Công thức Boutillon eq.(5):
```
G(s') = round(2^m' × √2 × cos(π × (s' + 0.5) / 512))
```

### Tại sao nhân √2?
Để output range là [0, √2·2^m'] thay vì [0, 2^m']. Hệ số √2 này kết hợp
với Fr (chứa √(-2·ln(x))) → tích Fr×G = √(-2·ln(x)) × √2·cos(...) = chính xác
Box-Muller transform (trừ sai số quantization).

### 256 entries vì sao?
- s' dùng 8 bit (0..255) → 256 entries
- Cosine có symmetry → chỉ cần 1/4 chu kỳ
- 256 × 8 bits = 256 bytes → fit trong 1 Block RAM nhỏ nhất trên FPGA

### ❓ Thầy hỏi: "Sao không dùng CORDIC thay vì LUT cho cosine?"
> **Trả lời**: CORDIC cho accuracy cao hơn nhưng tốn nhiều cycle (iterative) và logic.
> LUT 256 bytes cho accuracy đủ tốt khi kết hợp CLT, và throughput 1 cycle/lookup.
> Đây là trade-off accuracy ↔ resource theo philosophy của Boutillon.

---

## 9. box_muller_fixed.m — Lõi Box-Muller (phần PHỨC TẠP NHẤT)

### Flow chi tiết

**Bước 1: Extract bits từ URNG 32-bit**
```
URNG = [b31 b30 b29 ... b1 b0]  (32-bit unsigned)

→ Đếm leading zeros (LZ): xác định r (partition level)
   Nếu bit 31 = 1: r=1 (LZ=0)
   Nếu bits 31-28 = 0000, bit 27 = 1: r=2 (LZ=4)
   ...
   r = min(floor(LZ/4) + 1, K=5)

→ s = 4 bits ngay sau leading zeros (sub-segment index)
→ s' = bits[7:0] (8-bit cosine index)
→ sign = bit[8] (1-bit)
```

**Bước 2: ROM lookup**
```
Fr_val = Fr_table[r][s]     → 9-bit unsigned
G_val  = G_table[s']        → 8-bit signed
```

**Bước 3: Multiply**
```
P = Fr_val × G_val          → 17-bit signed (9 unsigned × 8 signed)
```

**Bước 4: Truncate (round-half-up)**
```
Shift = m + m' - B = 7 + 7 - 6 = 8 bits
P_rounded = floor((P + 2^7) / 2^8)   ← cộng half rồi floor = round-half-up
```

**Bước 5: Apply sign (Boutillon eq.7)**
```
nếu sign = 0: output = P_rounded
nếu sign = 1: output = -P_rounded - 1    ← 1's complement, KHÔNG PHẢI 2's complement!
```

### Tại sao 1's complement (-P-1) thay vì 2's complement (-P)?
Đây là điểm TINH TẾ nhất trong paper Boutillon:
- 2's complement: range [-N, +N-1] → asymmetric → mean ≠ 0
- 1's complement: range [-(N-1), +N-1] → symmetric nhưng mean = -0.5 LSB
- Mean = -2^(-B-1) → SAI SỐ CÓ HỆ THỐNG, nhưng BIẾT TRƯỚC → CLT sẽ BÙ

### ❓ Thầy hỏi: "Leading zero count có tốn logic trên FPGA không?"
> **Trả lời**: Có — priority encoder hoặc cascaded comparator. Nhưng chỉ cần K=5 mức,
> mỗi mức check 4 bits → 5-stage if/else đơn giản, latency 1 cycle. Xilinx Vivado
> sẽ optimize thành LUT cascade rất nhỏ.

### ❓ Thầy hỏi: "Tại sao sign lấy ở bit[8]?"
> **Trả lời**: Bit allocation: bits[31:8+1] cho leading zero + s, bits[7:0] cho s',
> bit[8] "thừa" giữa 2 vùng → dùng cho sign. Random bit nào cũng được (vì URNG
> tốt thì mọi bit đều uniform), miễn KHÔNG trùng với bits đã dùng cho r, s, s'.

---

## 10. clt_acc_fixed.m — CLT Accumulator (fixed-point)

### Khác biệt với clt_acc.m (float):
| | Float | Fixed |
|---|---|---|
| Input | double, ~ N(0,1) | int16, Q(1.6) |
| Sum | double | int32 (tránh overflow) |
| Mean comp | Không cần | Cộng +2 (bù -A·2^(-B-1)) |
| Scale | Chia √4 = 2.0 | Right shift 1 bit (free) |

### Mean compensation chi tiết:
```
Mỗi BM sample có mean = -2^(-B-1) = -2^(-7) = -1/128      (do 1's complement sign)
Sum 4 samples: mean = -4/128 = -1/32
Trong Q(_.6) integer: -1/32 × 2^6 = -2
→ Compensation: cộng +2 vào sum
```

### Tại sao scale bằng right shift?
```
std sau sum = √A = √4 = 2 = 2^1
→ Chia 2 = shift right 1 bit trong Verilog: wire [N-1:0] scaled = sum >>> 1;
→ Không tốn logic, không tốn cycle → "free" normalization
```
Đây là lý do chính chọn A=4: vì √4 là lũy thừa 2.

### ❓ Thầy hỏi: "Nếu A=8 thì scale thế nào?"
> **Trả lời**: √8 = 2√2, không phải lũy thừa 2 → cần multiplier thật (DSP slice).
> A=16 thì √16 = 4 = 2² → shift 2 bits, cũng free. Nhưng A=16 giảm throughput
> 16× → quá chậm. A=4 là sweet spot: scale free + throughput hợp lý.

---

## 11. awgn_fixed_top.m — Pipeline đầy đủ (fixed-point)

### Thứ tự gọi:
```
1. Load fr_table.mat, g_table.mat (nếu chưa có → gọi fr_rom_gen, g_rom_gen)
2. taus_urng_fixed(N×A, seed) → urng_seq [uint32]
3. for i = 1:N×A: box_muller_fixed(urng_seq[i], fr_table, g_table) → bm_seq [int16]
4. for j = 1:N:   clt_acc_fixed(bm_seq[j*4-3:j*4]) → noise[j] [int16]
```

### Output format: int16, Q(2.6)
- Giá trị integer 64 = giá trị float 1.0
- Range: ±512 (int) = ±8.0 (float) — đủ cho ±4σ
- Để convert sang float: `noise_float = double(noise_int) / 2^6`

---

# PHẦN C: VERIFICATION & TESTING

---

## 12-13. test_quantize_utils.m + test_taus_urng_fixed.m

### Mục đích: Bắt bug SỚM
Test từng function riêng lẻ TRƯỚC KHI dùng trong pipeline.
Nếu round_half_up sai 1 LSB → toàn bộ pipeline sai → debug rất khó.

### test_taus_urng_fixed đặc biệt quan trọng:
- In ra 10 output đầu tiên dưới dạng HEX → paste vào Verilog testbench để compare
- KS test verify uniform distribution
- Check không có collision (unique values) → period đủ dài

---

## 14. compare_float_vs_fixed.m — So sánh D1 vs D2

### LƯU Ý QUAN TRỌNG:
D1 và D2 **KHÔNG cho ra cùng sequence** vì:
- D1: dùng `sin()`, `cos()`, `log()` floating-point (chính xác 64-bit)
- D2: dùng LUT 256 entries (chính xác ~8-bit)

→ Chỉ compare **thống kê** (histogram, mean, std, PSD, tail), KHÔNG compare sample-by-sample.

### Tiêu chí chấp nhận:
- |mean| < 0.01
- |std - 1| < 0.05
- PDF MSE < 5×10^(-4)
- PDF max error < 1%

Nếu tất cả pass → D2 đủ tốt để làm golden cho RTL.

### ❓ Thầy hỏi: "Sao D1 và D2 khác nhau? Cùng thuật toán mà"
> **Trả lời**: D1 dùng hàm toán học chính xác (sin, cos, log), D2 dùng LUT xấp xỉ
> (Boutillon). D1 là reference "nên ra gì", D2 là "hardware sẽ ra gì".
> Sự khác biệt nhỏ giữa D1 và D2 chính là quantization error — được smooth bởi CLT.

---

## 15. run_d2_pipeline.m — Master script

### Chạy 1 lệnh → build mọi thứ:
```
Step 1: Test quantize utils       → fail ở đây = bug cơ bản
Step 2: Generate ROM tables       → sinh fr_table, g_table
Step 3: Test URNG                 → verify determinism + uniformity
Step 4: Run pipeline 50k samples  → sanity check mean/std
Step 5: Compare float vs fixed    → acceptance criteria
Step 6: Generate golden vectors   → ready cho RTL co-sim
```

---

## 16. run_all_verify.m — Verification suite (sim01-07 gộp)

### Bao gồm:
- **SIM01**: URNG uniformity (histogram + KS test)
- **SIM02**: Box-Muller histogram vs N(0,1) + Q-Q plot
- **SIM03**: CLT effect — so sánh A=1,2,4,8 (4 histogram chồng)
- **SIM05**: PSD flatness (Welch periodogram)
- **SIM06**: Autocorrelation (kỳ vọng delta function)
- **SIM07**: Chi-squared + KS test for normality

### ❓ Thầy hỏi: "PSD phẳng nghĩa là gì?"
> **Trả lời**: AWGN có Power Spectral Density = hằng số ở mọi tần số (white noise).
> Nếu PSD có peak hoặc dip → noise bị "tô màu" (colored noise) → không phải white.
> Welch periodogram cho phép estimate PSD và verify flatness.

### ❓ Thầy hỏi: "Chi-squared test hoạt động thế nào?"
> **Trả lời**: Chia output thành bins, đếm số sample mỗi bin (Observed).
> Tính Expected count từ PDF N(0,1). Statistic χ² = Σ(O-E)²/E.
> Nếu χ² < critical value (tra bảng theo df và α=0.05) → output phù hợp Gaussian.
> p-value > 0.05 = PASS.

---

# PHẦN D: GOLDEN VECTORS & BER

---

## 17. golden_gen.m — Sinh golden vectors cho RTL

### Output 5 file text:
| File | Nội dung | Dùng cho |
|---|---|---|
| golden_config.txt | Seed, N, A, B | Testbench parameter |
| golden_urng.txt | URNG output (hex 32-bit) | Verify taus_urng.v |
| golden_bm.txt | BM output (signed hex 16-bit) | Verify bm_core.v |
| golden_clt.txt | CLT output (signed hex) | Verify awgn_top.v (QUAN TRỌNG NHẤT) |
| golden_bm_debug.txt | Chi tiết r, s, s', Fr, G, P... | Debug khi mismatch |

### Cách RTL testbench dùng:
```verilog
$readmemh("golden_clt.txt", expected);
...
if (clt_out !== expected[i])
    $display("MISMATCH at cycle %d", i);
```

### ❓ Thầy hỏi: "Nếu RTL và MATLAB khác nhau 1 bit thì sao?"
> **Trả lời**: 1 bit mismatch = bug. Nguyên nhân thường gặp:
> (1) Rounding mode khác nhau (round-half-up vs truncate)
> (2) Signed vs unsigned nhầm lẫn
> (3) Pipeline delay — RTL output trễ N cycle so với golden
> (4) Reset polarity (active-HIGH vs LOW)
> Dùng golden_bm_debug.txt để trace signal nào sai đầu tiên.

---

## 18. sim04_bitwidth_sweep.m — Chứng minh B=6

### Làm gì:
Chạy fixed-point pipeline với B = {4, 6, 8, 10}, mỗi lần re-generate ROM tables
với m = m' = B+1 (theo Boutillon). So sánh MSE và ROM size.

### Kết quả mong đợi:
```
B = 4:  MSE cao, ROM nhỏ nhất        → quantization thô, tail kém
B = 6:  MSE thấp, ROM vừa phải       → SWEET SPOT ← chọn cái này
B = 8:  MSE thấp hơn, ROM lớn hơn    → improvement nhỏ, cost lớn
B = 10: MSE gần B=8, ROM rất lớn     → diminishing returns
```

### ❓ Thầy hỏi: "MSE cụ thể bao nhiêu là chấp nhận được?"
> **Trả lời**: MSE PDF < 5×10^(-4) là tiêu chí. Với B=6, MSE thường khoảng 10^(-4),
> nghĩa là histogram gần như trùng với PDF lý tưởng khi plot.

---

## 19. sim09_ber_bpsk.m — BER BPSK (MONEY SHOT)

### Tại sao đây là "money shot"?
Nếu noise generator tạo ra **đúng** phân bố Gaussian, đường BER thực nghiệm
PHẢI khớp với công thức lý thuyết. Bất kỳ sai lệch nào > 0.5 dB đều
chỉ ra vấn đề trong generator.

### BPSK channel model:
```
TX: bit → {-1, +1}    (Eb = 1)
Channel: rx = tx + noise
RX: rx > 0 → bit=1, rx < 0 → bit=0
```

### Noise scaling:
```
Eb/N0 (dB) → convert sang linear → N0 = 1/EbN0_lin → σ = √(N0/2)
noise_scaled = σ × noise_unit_variance
```
Nếu noise_unit_variance thực sự có std = 1 → BER sẽ khớp lý thuyết.

### So sánh 3 nguồn:
1. `randn` (MATLAB built-in) — gold standard
2. D1 Float model — verify thuật toán
3. D2 Fixed-point — verify hardware model

Cả 3 phải khớp nhau và khớp theory.

### Gap analysis:
Tìm Eb/N0 cần thiết để đạt BER = 10^(-4) cho mỗi nguồn.
Gap < 0.5 dB = PASS.

### ❓ Thầy hỏi: "Tại sao dùng qfunc thay vì erfc?"
> **Trả lời**: Cả hai tương đương: Q(x) = 0.5×erfc(x/√2).
> MATLAB có sẵn `qfunc()` trong Communications Toolbox.
> Nếu không có Comm Toolbox: `ber = 0.5 * erfc(sqrt(EbN0_lin))`.

### ❓ Thầy hỏi: "1 triệu bit có đủ không?"
> **Trả lời**: Với 10^6 bits, có thể measure BER đáng tin cậy đến ~10^(-5).
> Rule of thumb: cần ~100 errors tối thiểu → tại BER 10^(-5) cần 10^7 bits.
> Nếu thầy yêu cầu thấp hơn 10^(-5), tăng N_bits_per_snr lên 10^7.

---

## 20. sim10_ber_qpsk.m — BER QPSK + Independence check

### Mở rộng so với BPSK:
QPSK dùng 2 kênh I và Q **độc lập** → cần 2 chuỗi noise **khác seed**.
Nếu I và Q noise correlated → SER sẽ sai lệch so với theory.

### Gray mapping:
```
00 → (-1, -1)    01 → (-1, +1)
10 → (+1, -1)    11 → (+1, +1)
```

### BER QPSK = BER BPSK (lý thuyết):
Vì mỗi kênh I, Q giải điều chế BPSK độc lập → BER/bit giống nhau.

### Independence test:
Tỉ số SER/BER nên khớp lý thuyết: SER = 1 - (1-BER)^2.
Nếu deviation > 10% → noise I và Q bị correlated.

### Constellation plot:
Tại 1 SNR (ví dụ 8 dB), vẽ scatter (rx_I, rx_Q) → 4 đám mây quanh
4 điểm lý tưởng (±1, ±1). Đẹp và trực quan cho slide bảo vệ.

### ❓ Thầy hỏi: "Sao seed I và seed Q phải khác nhau?"
> **Trả lời**: Cùng seed → cùng chuỗi noise → noise I = noise Q → hoàn toàn correlated
> → performance khác hẳn lý thuyết. Seed khác → chuỗi Tausworthe khác → noise
> thống kê độc lập (period 2^88 đủ dài để 2 chuỗi không overlap).

---

# CÂU HỎI TỔNG HỢP THẦY CÓ THỂ HỎI

### Q: "Tóm tắt flow từ đầu đến cuối?"
> URNG (Tausworthe 3-component, period 2^88) → sinh 32-bit uniform
> → extract r, s, s', sign từ 32 bits
> → Fr ROM lookup + G ROM lookup
> → nhân Fr × G → round-half-up truncate → apply sign
> → CLT accumulate 4 samples + mean compensation + scale (shift right 1 bit)
> → output ~ N(0,1) trong Q(2.6) format

### Q: "Tổng ROM bao nhiêu byte?"
> Fr: 5 levels × 16 entries × 9 bits = 720 bits = 90 bytes
> G: 256 entries × 8 bits = 2048 bits = 256 bytes
> Tổng: **346 bytes** — cực kỳ nhỏ, fit trong bất kỳ FPGA nào.

### Q: "Accuracy bao nhiêu?"
> Relative error < 0.1% trong ±4σ (verify bằng chi-squared test).
> BER gap < 0.5 dB so với lý thuyết (verify bằng sim09).

### Q: "Throughput bao nhiêu?"
> URNG: 1 sample/cycle → 50 MHz = 50 Msamples/s
> BM: 1 sample/cycle
> CLT: cần 4 BM samples → output rate = 50/4 = **12.5 Msamples/s**

---

*Cập nhật file này khi phát hiện thêm câu hỏi bảo vệ.*
