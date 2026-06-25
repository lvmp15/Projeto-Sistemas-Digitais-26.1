# ============================================================
#  run.do - Compila e simula o SafeCrack Pro no ModelSim
#  Uso no console do ModelSim:  do run.do
#  (execute a partir da pasta onde estao os arquivos .sv)
# ============================================================

# Cria a biblioteca de trabalho
if {[file exists work]} { vdel -all }
vlib work

# Compila o projeto (SystemVerilog)
vlog -sv ../SafeCrackPro.sv
vlog -sv ../SafeCrackPro_tb.sv

# Abre a simulacao
vsim -voptargs=+acc work.SafeCrackPro_tb

# Carrega a configuracao de ondas
do wave.do

# Roda ate o $finish do testbench
run -all

# Ajusta o zoom para mostrar toda a simulacao
wave zoom full
