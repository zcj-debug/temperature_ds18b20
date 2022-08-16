onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_ds18b20/U_ds18b20/clk
add wave -noupdate /tb_ds18b20/U_ds18b20/rst_n
add wave -noupdate /tb_ds18b20/U_ds18b20/press
add wave -noupdate /tb_ds18b20/U_ds18b20/dq_in
add wave -noupdate /tb_ds18b20/U_ds18b20/dq_out
add wave -noupdate /tb_ds18b20/U_ds18b20/data_out
add wave -noupdate /tb_ds18b20/U_ds18b20/state_c
add wave -noupdate /tb_ds18b20/U_ds18b20/state_n
add wave -noupdate /tb_ds18b20/U_ds18b20/idle2init
add wave -noupdate /tb_ds18b20/U_ds18b20/init2skrom
add wave -noupdate /tb_ds18b20/U_ds18b20/skrom2set
add wave -noupdate /tb_ds18b20/U_ds18b20/skrom2convert
add wave -noupdate /tb_ds18b20/U_ds18b20/skrom2read
add wave -noupdate /tb_ds18b20/U_ds18b20/set2idle
add wave -noupdate /tb_ds18b20/U_ds18b20/convert2idle
add wave -noupdate /tb_ds18b20/U_ds18b20/read2idle
add wave -noupdate -radix unsigned /tb_ds18b20/U_ds18b20/cnt_400ms
add wave -noupdate /tb_ds18b20/U_ds18b20/add_cnt_400ms
add wave -noupdate /tb_ds18b20/U_ds18b20/end_cnt_400ms
add wave -noupdate -radix unsigned /tb_ds18b20/U_ds18b20/MAX_slot
add wave -noupdate -radix unsigned /tb_ds18b20/U_ds18b20/MAX_bit
add wave -noupdate -radix unsigned /tb_ds18b20/U_ds18b20/MAX_byte
add wave -noupdate -radix unsigned /tb_ds18b20/U_ds18b20/cnt_slot
add wave -noupdate /tb_ds18b20/U_ds18b20/add_cnt_slot
add wave -noupdate /tb_ds18b20/U_ds18b20/end_cnt_slot
add wave -noupdate -radix unsigned /tb_ds18b20/U_ds18b20/cnt_bit
add wave -noupdate /tb_ds18b20/U_ds18b20/add_cnt_bit
add wave -noupdate /tb_ds18b20/U_ds18b20/end_cnt_bit
add wave -noupdate -radix unsigned /tb_ds18b20/U_ds18b20/cnt_byte
add wave -noupdate /tb_ds18b20/U_ds18b20/add_cnt_byte
add wave -noupdate /tb_ds18b20/U_ds18b20/end_cnt_byte
add wave -noupdate -radix hexadecimal /tb_ds18b20/U_ds18b20/send_data
add wave -noupdate /tb_ds18b20/U_ds18b20/flag_set
add wave -noupdate /tb_ds18b20/U_ds18b20/flag_convert
add wave -noupdate /tb_ds18b20/U_ds18b20/flag_read
add wave -noupdate /tb_ds18b20/U_ds18b20/receive_en
add wave -noupdate /tb_ds18b20/U_ds18b20/receive_data
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {523475040 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {24100675 ns} {36807775 ns}
