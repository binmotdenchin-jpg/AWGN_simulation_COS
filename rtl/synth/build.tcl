#======================================================================
# build.tcl — Vivado non-project (batch) synthesis + implementation
#----------------------------------------------------------------------
# Chạy:  vivado -mode batch -source build.tcl
# Sinh:  reports/utilization.rpt, reports/timing.rpt, reports/power.rpt
#        awgn_top.dcp (checkpoint)
#
# Yêu cầu: fr_table.txt, g_table.txt nằm cùng thư mục (cho $readmemh).
#======================================================================

set PART     xc7a100tcsg324-1
set TOP      awgn_top
set SRC_DIR  ../src
set OUT_DIR  ./reports

file mkdir $OUT_DIR

# --- Read RTL ---
read_verilog [list \
    $SRC_DIR/taus_urng.v \
    $SRC_DIR/lzc32.v \
    $SRC_DIR/fr_rom.v \
    $SRC_DIR/g_rom.v \
    $SRC_DIR/bm_core.v \
    $SRC_DIR/clt_acc.v \
    $SRC_DIR/awgn_top.v \
]

# --- ROM init files cho $readmemh (copy vào CWD trước khi chạy) ---
# Đảm bảo fr_table.txt và g_table.txt ở thư mục hiện hành.

read_xdc awgn_top.xdc

# --- Synthesis ---
synth_design -top $TOP -part $PART -flatten_hierarchy rebuilt
write_checkpoint -force $OUT_DIR/post_synth.dcp
report_utilization -file $OUT_DIR/utilization_synth.rpt
report_timing_summary -file $OUT_DIR/timing_synth.rpt

# --- Implementation ---
opt_design
place_design
phys_opt_design
route_design
write_checkpoint -force ${TOP}.dcp

# --- Reports ---
report_utilization        -file $OUT_DIR/utilization.rpt
report_timing_summary     -file $OUT_DIR/timing.rpt
report_power              -file $OUT_DIR/power.rpt
report_clock_utilization  -file $OUT_DIR/clock_util.rpt

# --- In tóm tắt ra console ---
puts "================ SUMMARY ================"
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
puts "Worst Negative Slack (WNS): $wns ns"
puts "Reports written to $OUT_DIR/"
puts "========================================="
