add_background "debug debug_symbols"
add_back_button "debug" [translate "debug"]
add_back_button "debug_symbols" [translate "symbols"]

add_de1_text "debug" 180 300 -text "Grid" -font [get_font "Mazzard SemiBold" 18] -fill $::color_text -anchor "w" 
create_button "debug" 680 240 880 360 [translate "off"] [get_font "Mazzard SemiBold" 18] $::color_button $::color_button_text { say [translate "off"] $::settings(sound_button_in); .can itemconfigure "grid" -state "hidden" }
create_button "debug" 980 240 1180 360 [translate "on"] [get_font "Mazzard SemiBold" 18] $::color_button $::color_button_text { say [translate "on"] $::settings(sound_button_in); .can itemconfigure "grid" -state "normal" }

create_button "debug" 180 420 1180 540 [translate "symbols"] $::font_button $::color_button $::color_button_text { say [translate "symbols"] $::settings(sound_button_in); metric_jump_to "debug_symbols"}



add_de1_text "debug_symbols" 180 420 -text "$::symbol_temperature temperature" -font [get_font "Mazzard Regular" 28] -fill $::color_text -anchor "nw" 
add_de1_text "debug_symbols" 180 520 -text "$::symbol_espresso espresso $::symbol_filter filter $::symbol_water water $::symbol_steam steam $::symbol_flush flush" -font [get_font "Mazzard Regular" 28] -fill $::color_text -anchor "nw" 
add_de1_text "debug_symbols" 180 620 -text "$::symbol_hand stop" -font [get_font "Mazzard Regular" 28] -fill $::color_text -anchor "nw" 
add_de1_text "debug_symbols" 180 720 -text "$::symbol_tick tick $::symbol_ratio cross $::symbol_menu menu" -font [get_font "Mazzard Regular" 28] -fill $::color_text -anchor "nw" 
add_de1_text "debug_symbols" 180 820 -text "$::symbol_bean coffee $::symbol_tea tea" -font [get_font "Mazzard Regular" 28] -fill $::color_text -anchor "nw" 
add_de1_text "debug_symbols" 180 920 -text "$::symbol_grind grind" -font [get_font "Mazzard Regular" 28] -fill $::color_text -anchor "nw" 
add_de1_text "debug_symbols" 180 1020 -text "$::symbol_box unchecked box $::symbol_box_checked checked box" -font [get_font "Mazzard Regular" 28] -fill $::color_text -anchor "nw" 
add_de1_text "debug_symbols" 180 1120 -text "$::symbol_star star $::symbol_star_outline star outline" -font [get_font "Mazzard Regular" 28] -fill $::color_text -anchor "nw" 
add_de1_text "debug_symbols" 180 1220 -text "$::symbol_de1 DE1 $::symbol_niche Niche Zero" -font [get_font "Mazzard Regular" 28] -fill $::color_text -anchor "nw" 
add_de1_text "debug_symbols" 180 1320 -text "$::symbol_battery_0 0% $::symbol_battery_25 25% $::symbol_battery_50 50% $::symbol_battery_75 75% $::symbol_battery_100 100% $::symbol_bluetooth Bluetooth $::symbol_wifi WiFi $::symbol_usb USB" -font [get_font "notosansuiregular" 28] -fill $::color_text -anchor "nw" 
