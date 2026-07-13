# RTL Verilog — AWGN Generator (Box-Muller + CLT)

Bit-accurate RTL khớp 100% với MATLAB fixed-point golden model (D2).
Phương pháp Boutillon–Danger–Ghazel (ICECS'00). Verify bằng Icarus Verilog 12.0.

## Module (D3)

| File | Vai trò | Golden tương ứng | Bit-width chính |
|---|---|---|---|
| `src/taus_urng.v` | Combined Tausworthe URNG (3×LFSR, period ~2⁸⁸) | `taus_urng_fixed.m` | out 32b |
| `src/lzc32.v` | LZC 32-bit (binary-search 5 tầng, tối ưu Fmax) | vòng for trong `box_muller_fixed.m` | 0..32 |
| `src/fr_rom.v` | Fr(s) ROM, K=5×16=80 words | `fr_rom_gen.m` | **FR_W=9** unsigned Q2.7 |
| `src/g_rom.v` | G(s') ROM, 256 words | `g_rom_gen.m` | **G_W=9** signed Q1.7 |
| `src/bm_core.v` | Box-Muller: extract→lookup→mult→round→sign | `box_muller_fixed.m` | P 20b, bm 16b Q1.6 |
| `src/clt_acc.v` | CLT accumulator A=4 + mean comp + scale | `clt_acc_fixed.m` | out 16b Q2.6 |
| `src/awgn_top.v` | Top-level glue | `awgn_fixed_top.m` | — |

## Testbench (D4)

| File | Kiểm tra | Kết quả |
|---|---|---|
| `tb/tb_urng.v` | URNG vs `golden_urng.txt` (8000) | ✅ 0 errors |
| `tb/tb_awgn_datapath.v` | BM (8000) + CLT (2000) vs golden | ✅ 0 errors |
| `tb/tb_awgn_top.v` | Pipeline đầy đủ self-driving (2000) | ✅ 0 errors |
| `tb/tb_awgn_pause.v` | Tạm dừng `en` giữa chừng, PIPE=0 & PIPE=1 (2000) | ✅ 0 errors (Python co-sim) |

## ⚠️ Lưu ý quan trọng về bit-width ROM (đã sửa trong mã)

- **Fr** (công thức đúng √(-ln x) theo Boutillon eq.1): max = **470** → vừa **9 bit**
  unsigned (đúng 2+m=9). `FR_W=9`. (Lỗi √(-2ln x) cũ thổi Fr max lên 665 nên tưởng cần 10 bit.)
- **|G| max = 181** (= √2·128) → cần **9 bit** signed (tài liệu ghi 1+m'=8 KHÔNG đủ vì 181>127). `G_W=9`.

→ `g_rom_gen.m` đã đặt `info.word_bits=9` để 2's-complement giá trị âm nạp đúng.
  `fr_rom_gen.m` đã sửa thành √(-ln x). `gen_golden.py` khớp công thức này và sinh
  `fr_table.txt`/`g_table.txt` (3 hex digit) đúng width.

## Round-half-up (đã kiểm chứng bit-exact)

`(P + 2^(shift-1)) >>> shift` (arithmetic shift) khớp **chính xác** `floor((P+half)/2^shift)`
của MATLAB với mọi P signed (kiểm tra ±200k, 0 mismatch). Áp dụng cho:
- BM truncate: shift = m+m'-B = 8
- CLT scale: shift = log2(√A) = 1

## Chạy mô phỏng

### Icarus Verilog (đã test)
```bash
cd rtl
python3 gen_golden.py tb 2000          # sinh ROM + golden vào tb/

cd tb
# URNG
iverilog -g2012 -o sim_urng ../src/taus_urng.v tb_urng.v && vvp sim_urng
# Datapath
iverilog -g2012 -o sim_dp ../src/lzc32.v ../src/fr_rom.v ../src/g_rom.v \
    ../src/bm_core.v ../src/clt_acc.v tb_awgn_datapath.v && vvp sim_dp
# Top-level
iverilog -g2012 -o sim_top ../src/*.v tb_awgn_top.v && vvp sim_top
```

### ModelSim/Questa
```tcl
cd rtl/sim
vsim -c -do run_sim.do    # cần copy fr_table/g_table/golden_*.txt vào sim/
```

## Các sửa đổi & tối ưu (bản này)

1. **Sửa lỗi `valid` của `taus_urng`** — trước đây `valid` giữ mức 1 khi `en=0`,
   khiến `bm_core`/`clt_acc` tiêu thụ lại cùng một word khi pipeline tạm dừng
   (co-sim: 1969/2000 mẫu sai với en-toggling). Nay `valid` là strobe
   "rng_out vừa cập nhật cycle này". Với `en=1` liên tục, hành vi không đổi.
2. **`lzc32` binary-search** — thay chuỗi ưu tiên 32 tầng bằng 5 tầng halving
   (độ sâu logic O(log₂32)), rút ngắn critical path đầu datapath. Đã kiểm chứng
   tương đương bit-exact (mọi lớp lz + 10⁶ vector ngẫu nhiên, 0 mismatch).
3. **`bm_core` tham số `PIPE`** (mặc định 0 — giữ nguyên hành vi cũ):
   `PIPE=1` chèn 1 stage đăng ký {Fr, G, sign} giữa (LZC+extract+ROM) và
   (mult+round+sat) → cắt đôi critical path, tăng Fmax. Latency +1 cycle,
   giá trị output không đổi, throughput không đổi. `awgn_top` expose `PIPE`.
4. **`tb_awgn_pause.v`** — testbench mới kiểm tra en-toggling cho cả PIPE=0/1.
5. **`rtl_cosim.py`** — bộ đồng mô phỏng cycle-accurate bằng Python (không cần
   simulator): `python3 rtl_cosim.py tb` chạy 6 cấu hình
   {PIPE=0/1} × {en liên tục, tạm dừng, ngẫu nhiên} so với golden. Tất cả PASS.

## Timing & throughput

- URNG: 1 cycle/word (registered)
- ROM: combinational (đọc cùng cycle)
- bm_core: 1 cycle latency (registered bm_out)
- CLT: gom A=4 → 1 output mỗi 4 cycles
- **Throughput = 1/A = 0.25 sample/cycle**. Ở 50 MHz → 12.5 MS/s (> 10 MHz mục tiêu ✓)

## Còn lại (chưa làm)

- D6: Synthesis report Vivado (LUT/FF/BRAM/DSP/Fmax) — RTL đã synthesizable.
  Khi build, thử cả `PIPE=0` và `PIPE=1` để so Fmax
  (`synth_design ... -generic PIPE=1` hoặc đặt tham số ở wrapper).
