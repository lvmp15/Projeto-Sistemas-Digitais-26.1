# ============================================================
#  wave.do - Configura as ondas exibidas no ModelSim
# ============================================================
onerror {resume}
quietly WaveActivateNextPane {} 0

# ---- Entradas ----
add wave -divider "Entradas"
add wave -label CLOCK_50            sim:/SafeCrackPro_tb/CLOCK_50
add wave -label KEY -radix binary   sim:/SafeCrackPro_tb/KEY

# ---- Estado interno da FSM ----
add wave -divider "FSM"
add wave -label estado              sim:/SafeCrackPro_tb/dut/state
add wave -label key_press -radix binary sim:/SafeCrackPro_tb/dut/key_press
add wave -label digito_ativo -radix unsigned sim:/SafeCrackPro_tb/dut/active_idx

# ---- Digitos armazenados ----
add wave -divider "Digitos (dig[0..3])"
add wave -label dig0 -radix unsigned sim:/SafeCrackPro_tb/dut/dig\[0\]
add wave -label dig1 -radix unsigned sim:/SafeCrackPro_tb/dut/dig\[1\]
add wave -label dig2 -radix unsigned sim:/SafeCrackPro_tb/dut/dig\[2\]
add wave -label dig3 -radix unsigned sim:/SafeCrackPro_tb/dut/dig\[3\]

# ---- Saidas (LEDs) ----
add wave -divider "Saidas"
add wave -label LEDG -radix hexadecimal sim:/SafeCrackPro_tb/LEDG
add wave -label LEDR -radix hexadecimal sim:/SafeCrackPro_tb/LEDR

configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -timelineunits ns
update
