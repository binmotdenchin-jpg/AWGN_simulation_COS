# Bộ sinh AWGN — Box-Muller + CLT (đồ án hoàn chỉnh)

Thiết kế và kiểm chứng bộ sinh nhiễu Gauss cho channel emulation, phương pháp
Boutillon–Danger–Ghazel (ICECS 2000). Đồng thiết kế bit-accurate MATLAB ↔ RTL Verilog.


## Cấu trúc

```
matlab/               Mô hình MATLAB (nguồn)
  float_model/        D1 — dấu phẩy động (taus_urng, box_muller, clt_acc, awgn_float_top)
  fixed_model/        D2 — dấu phẩy tĩnh, golden (đã sửa fr_rom_gen.m, g_rom_gen.m)
  verify/             sim BER + bitwidth + demo (.m)
  golden_gen/         sinh golden vectors cho RTL
  docs/               design_decisions.md, giai_thich_matlab_code.md

rtl/                  D3 + D4 — RTL Verilog + đồng mô phỏng (FR_W=9, G_W=9)
  src/                7 module + fr_table.txt, g_table.txt
  tb/                 3 testbench + golden vectors
  sim/                ModelSim run_sim.do
  synth/              D6 — XDC + build.tcl Vivado + ước lượng tài nguyên
  gen_golden.py       sinh ROM + golden (bit-exact, khớp MATLAB đã sửa)
  README.md

verify/               D5 — mô phỏng & kiểm chứng (Python)
  awgn_model.py, sim_verify.py, sim_ber.py, sim_bitwidth.py
  figures/            8 hình PNG + 3 bảng số liệu

report/
  report.docx         BÁO CÁO CHÍNH (18 trang, 7 chương)
  *.js                mã sinh báo cáo
```

## Kết quả chính

| Hạng mục | Kết quả |
|---|---|
| Đồng mô phỏng RTL↔golden | **0 sai lệch** (URNG 8000, BM 8000, CLT 2000, top 2000) |
| Mô-men thống kê | mean +0,002; std 0,998; skew ≈0; kurt ≈2,98 |
| KS distance | 0,49% |
| BER BPSK/QPSK | trùng lý thuyết, tỉ số fixed/theory ≈ 0,97 |
| Bit-width | B=6 là điểm cân bằng; Fr=9 bit, G=9 bit |
| Tài nguyên (ước lượng) | ~280 LUT, ~150 FF, 1 DSP, 0–2 BRAM |
| Thông lượng | 12,5 MS/s @50MHz (> 10 MHz mục tiêu) |

## Hai sửa đổi đã áp dụng (xem chương 7 báo cáo)

1. **fr_rom_gen.m**: `sqrt(-2*log(x))` → `sqrt(-log(x))` (Boutillon eq.1). Kết quả std=1.
   Hệ quả: Fr max 665→470, vừa 9 bit đúng tài liệu (FR_W=9).
2. **g_rom_gen.m**: `word_bits = 1+m' (=8)` → `9`. Vì |G|max=181=√2·128 > 127 cần 9 bit
   có dấu; trước đây giá trị âm bị mã hóa bù-2 sai dấu.

`gen_golden.py` (sinh ROM/golden cho RTL) đã được chỉnh khớp đúng hai sửa đổi này.

## Cách chạy

```bash
# 1) RTL co-sim (cần iverilog) — sinh ROM/golden rồi chạy
cd rtl && python3 gen_golden.py tb 2000
cd tb && iverilog -g2012 -o s ../src/*.v tb_awgn_top.v && vvp s

# 2) Mô phỏng + vẽ hình (numpy/scipy/matplotlib)
cd ../../verify && python3 sim_verify.py && python3 sim_ber.py && python3 sim_bitwidth.py

# 3) Sinh lại báo cáo (node + npm i -g docx)
cd ../report && NODE_PATH=$(npm root -g) node make.js

# 4) Tổng hợp FPGA (Vivado) — lấy số LUT/FF/DSP/Fmax thật
cd ../rtl/synth && cp ../src/fr_table.txt ../src/g_table.txt . && vivado -mode batch -source build.tcl

# (MATLAB) chạy toàn bộ D2 + golden:  cd matlab/fixed_model && run_d2_pipeline
```


