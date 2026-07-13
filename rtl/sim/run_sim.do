#======================================================================
# run_sim.do — ModelSim/Questa compile + run script
#----------------------------------------------------------------------
# Chạy: vsim -c -do run_sim.do   (hoặc trong GUI: do run_sim.do)
# Yêu cầu: fr_table.txt, g_table.txt, golden_*.txt nằm trong thư mục sim.
#======================================================================
vlib work
vmap work work

# --- Compile RTL ---
vlog -sv ../src/taus_urng.v
vlog -sv ../src/lzc32.v
vlog -sv ../src/fr_rom.v
vlog -sv ../src/g_rom.v
vlog -sv ../src/bm_core.v
vlog -sv ../src/clt_acc.v
vlog -sv ../src/awgn_top.v

# --- Compile testbenches ---
vlog -sv ../tb/tb_urng.v
vlog -sv ../tb/tb_awgn_datapath.v
vlog -sv ../tb/tb_awgn_top.v
vlog -sv ../tb/tb_awgn_pause.v

# --- Run URNG test ---
vsim -c work.tb_urng
run -all
quit -sim

# --- Run datapath co-sim ---
vsim -c work.tb_awgn_datapath
run -all
quit -sim

# --- Run full top-level co-sim ---
vsim -c work.tb_awgn_top
run -all
quit -sim

# --- Run pause/en-toggling test (PIPE=0 + PIPE=1) ---
vsim -c work.tb_awgn_pause
run -all
quit -sim
