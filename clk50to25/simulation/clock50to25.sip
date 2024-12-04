set_global_assignment -entity "clock50to25" -library "lib_clock50to25" -name IP_TOOL_NAME "Qsys"
set_global_assignment -entity "clock50to25" -library "lib_clock50to25" -name IP_TOOL_VERSION "23.1"
set_global_assignment -entity "clock50to25" -library "lib_clock50to25" -name IP_TOOL_ENV "Qsys"
set_global_assignment -library "lib_clock50to25" -name SPD_FILE [file join $::quartus(sip_path) "../clock50to25.spd"]
set_global_assignment -library "lib_clock50to25" -name MISC_FILE [file join $::quartus(sip_path) "../../clock50to25.qsys"]

set_global_assignment -library "lib_clock50to25" -name MISC_FILE [file join $::quartus(sip_path) "clock50to25.vhd"]
set_global_assignment -library "lib_clock50to25" -name MISC_FILE [file join $::quartus(sip_path) "submodules/clock50to25_pll_0.vho"]
