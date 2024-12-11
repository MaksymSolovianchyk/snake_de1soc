set_global_assignment -entity "clock50to150" -library "lib_clock50to150" -name IP_TOOL_NAME "Qsys"
set_global_assignment -entity "clock50to150" -library "lib_clock50to150" -name IP_TOOL_VERSION "23.1"
set_global_assignment -entity "clock50to150" -library "lib_clock50to150" -name IP_TOOL_ENV "Qsys"
set_global_assignment -library "lib_clock50to150" -name SPD_FILE [file join $::quartus(sip_path) "../clock50to150.spd"]
set_global_assignment -library "lib_clock50to150" -name MISC_FILE [file join $::quartus(sip_path) "../../clock50to150.qsys"]

set_global_assignment -library "lib_clock50to150" -name MISC_FILE [file join $::quartus(sip_path) "clock50to150.vhd"]
set_global_assignment -library "lib_clock50to150" -name MISC_FILE [file join $::quartus(sip_path) "submodules/clock50to150_pll_0.vho"]
