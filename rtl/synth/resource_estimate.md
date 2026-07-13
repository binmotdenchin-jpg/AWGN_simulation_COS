# D6 — Ước lượng tài nguyên Synthesis (phân tích)

> ⚠️ Đây là **ước lượng phân tích** từ cấu trúc RTL. Số chính xác cần chạy
> `vivado -mode batch -source build.tcl` (xem `reports/utilization.rpt`).
> Ước lượng dưới đây để định cỡ và đối chiếu sanity-check sau khi synth.

## Target
- FPGA: Xilinx Artix-7 `xc7a100tcsg324-1` (Nexys A7) — đổi part tùy board
- Clock mục tiêu: 50 MHz (conservative); thử 100 MHz ở build thứ 2

## Ước lượng theo module

| Module | LUT | FF | DSP | BRAM | Ghi chú |
|---|---:|---:|---:|---:|---|
| `taus_urng` | ~90 | 96 | 0 | 0 | 3×32-bit state reg + XOR/shift (shift là wire, free) |
| `lzc32` | ~35 | 0 | 0 | 0 | priority encoder 32→6 |
| `fr_rom` | ~20 | 0 | 0 | 0/1 | 80×10b = 800b → distributed ROM (LUT) hoặc 1 BRAM18 |
| `g_rom` | ~30 | 0 | 0 | 0/1 | 256×9b = 2304b → distributed hoặc 1 BRAM18 |
| `bm_core` | ~60 | 16 | 1 | 0 | 1 multiplier 11×9 → 1 DSP48; round/sign/sat logic |
| `clt_acc` | ~40 | 38 | 0 | 0 | accumulator 20b + counter 3b + comp/scale |
| `awgn_top` (glue) | ~5 | 0 | 0 | 0 | wiring |
| **Tổng (distributed ROM)** | **~280** | **~150** | **1** | **0** | ROM nhỏ → để distributed |
| **Tổng (block ROM)** | **~230** | **~150** | **1** | **2** | nếu ép ROM vào BRAM |

> ROM ở đây rất nhỏ (Fr 800b + G 2.3Kb). Vivado thường suy ra **distributed
> ROM (LUT)** thay vì BRAM, trừ khi đặt `(* rom_style="block" *)` (đã đặt) hoặc
> kích thước vượt ngưỡng. Tùy version có thể ra 0 hoặc 2 BRAM18 — cả hai đều OK.

## Đối chiếu tham khảo

| Thiết kế | Phương pháp | LUT | FF | DSP | BRAM | Nhận xét |
|---|---|---:|---:|---:|---:|---|
| **Đồ án này (ước lượng)** | Box-Muller + CLT (LUT) | ~280 | ~150 | 1 | 0–2 | Đơn giản nhờ LUT-based |
| `crboth` (đo thực, Virtex-7) | Box-Muller (Lee 2006) | 1272 | 380 | 17 | 3 | log/sqrt/sin-cos → nặng hơn nhiều |

→ Phương pháp Boutillon (LUT-based Fr/G) rẻ hơn ~4–5× LUT và ~17× DSP so với
Lee 2006 (Chebyshev + CORDIC), đúng như kỳ vọng trong `design_decisions.md`.

## Timing (ước lượng)

- Critical path dự kiến: `bm_core` (multiplier 1 DSP + adder round + sign + saturate)
  hoặc đường ROM-read → multiply nếu ROM combinational.
- DSP48 có thể chạy >400 MHz; LUT logic round/sat ~vài ns. Critical path tổng
  combinational (ROM→mult→round→sign→sat) ước ~6–10 ns → **Fmax ~100–150 MHz**
  khả thi. Mục tiêu 50 MHz dư margin lớn.
- Throughput = 1/A = **0.25 sample/clock**. Ở 50 MHz → **12.5 MS/s** (> 10 MHz ✓).
  Ở 100 MHz → 25 MS/s.

## Tối ưu Fmax (nếu cần, ngoài scope)

1. Pipeline `bm_core`: tách ROM-read / multiply / round-sign-sat thành 3 stage.
2. Đăng ký ROM output (BRAM có reg sẵn) → cắt đường ROM→mult.
3. Khi pipeline, cần điều chỉnh `clt_acc` đếm theo `bm_valid` (đã hỗ trợ vì
   CLT gom theo handshake `bm_valid`, không phụ thuộc latency cố định).

## Checklist chạy synthesis thực

```bash
cd rtl/synth
cp ../src/fr_table.txt ../src/g_table.txt .   # cho $readmemh
vivado -mode batch -source build.tcl
# Xem: reports/utilization.rpt, reports/timing.rpt
```
