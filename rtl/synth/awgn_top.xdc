#======================================================================
# awgn_top.xdc — Timing & I/O constraints cho awgn_top.v
#----------------------------------------------------------------------
# Target: Xilinx Artix-7 (xc7a100tcsg324-1, vd Nexys A7). Đổi part nếu cần.
# Clock mục tiêu: 50 MHz (conservative). Thử 100 MHz ở build thứ 2.
#======================================================================

# --- Primary clock 50 MHz (chu kỳ 20 ns) ---
create_clock -name clk -period 20.000 [get_ports clk]

# Nếu thử 100 MHz: đổi period thành 10.000 và chạy lại để xem timing.
# create_clock -name clk -period 10.000 [get_ports clk]

# --- Input/Output delays (giả định nguồn/đích đồng bộ, margin 2 ns) ---
set_input_delay  -clock clk 2.000 [get_ports {rst_n en}]
set_output_delay -clock clk 2.000 [get_ports {noise_out[*] noise_valid}]

# --- False path cho reset (nếu reset bất đồng bộ ở mức cao hơn) ---
# set_false_path -from [get_ports rst_n]

#----------------------------------------------------------------------
# Pin assignment (VÍ DỤ cho Nexys A7 — sửa theo board thực tế).
# Bỏ comment khi map ra chân vật lý. Nếu chỉ synthesize OOC thì không cần.
#----------------------------------------------------------------------
# set_property -dict {PACKAGE_PIN E3  IOSTANDARD LVCMOS33} [get_ports clk]
# set_property -dict {PACKAGE_PIN C12 IOSTANDARD LVCMOS33} [get_ports rst_n]
# set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS33} [get_ports en]
