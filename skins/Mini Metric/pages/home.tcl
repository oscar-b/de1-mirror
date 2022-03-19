set espresso_contexts "off"
add_background $espresso_contexts
add_page_title $espresso_contexts [translate "decent espresso"]

create_symbol_button2 $espresso_contexts 2260 60 240 20 [translate "power"] $::symbol_power $::color_button_off { say [translate "power"] $::settings(sound_button_in); app_exit} 80 18

set ::water_button_id [create_symbol_button2 $espresso_contexts 600 500 360 30 [translate "hot water"] $::symbol_water $::color_button_water {say [translate "hot water"] $::settings(sound_button_in); do_start_water} 110]
set ::espresso_action_button_id [create_symbol_button2 $espresso_contexts 1080 480 400 30 [translate "espresso"] $::symbol_espresso $::color_button_espresso {say [translate {start}] $::settings(sound_button_in); do_start_espresso} 140]
set ::steam_button_id [create_symbol_button2 $espresso_contexts 1600 500 360 30 [translate "steam"] $::symbol_steam $::color_button_steam {say [translate "steam"] $::settings(sound_button_in); do_start_steam} 110]

set ::flush_button_id [create_symbol_button2 $espresso_contexts 800 1150 240 30 [translate "flush"] $::symbol_flush $::color_button_function {say [translate "flush"] $::settings(sound_button_in); do_start_flush} 72 18]
create_symbol_button2 $espresso_contexts 1160 1150 240 20 [translate "settings"] $::symbol_settings $::color_button_function { say [translate "settings"] $::settings(sound_button_in); show_android_navigation false; show_settings}  72 18
set ::lastshot_button_id [create_symbol_button2 $espresso_contexts 1520 1150 240 30 [translate "analysis"] $::symbol_chart $::color_button_function {say [translate "analysis"] $::settings(sound_button_in); do_show_last_shot } 72 18]

proc update_function_buttons {} {
	show_android_navigation true 

	if { [can_start_water] } {
		.can itemconfigure $::water_button_id -fill $::color_button_water
	} else {
		.can itemconfigure $::water_button_id -fill $::color_action_button_disabled
	}

	if { [can_start_steam] } {
		.can itemconfigure $::steam_button_id -fill $::color_button_steam
	} else {
		.can itemconfigure $::steam_button_id -fill $::color_action_button_disabled
	}	

	if { [can_start_espresso] } {
		.can itemconfigure $::espresso_action_button_id -fill $::color_button_espresso
	} else {
		.can itemconfigure $::espresso_action_button_id -fill $::color_action_button_disabled
	}

	if { [can_start_flush] } {
		.can itemconfigure $::flush_button_id -fill $::color_button_function
	} else {
		.can itemconfigure $::flush_button_id -fill $::color_action_button_disabled
	}

	if { [can_show_last_shot] } {
		.can itemconfigure $::lastshot_button_id -fill $::color_button_function
	} else {
		.can itemconfigure $::lastshot_button_id -fill $::color_action_button_disabled
	}
}
add_de1_variable $espresso_contexts -100 -100 -textvariable {[update_function_buttons]}
