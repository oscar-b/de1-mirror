set status_meter_contexts "off espresso_menu_profile espresso_menu_beans espresso_menu_grind espresso_menu_dose espresso_menu_ratio espresso_menu_yield espresso_menu_temperature espresso_done steam water flush"

# Water
set water_meter_background_id [.can create oval [rescale_x_skin 2140] [rescale_y_skin 1230] [rescale_x_skin 2580] [rescale_y_skin 1670] -fill $::color_status_bar -width 0 -state "hidden"]
add_visual_items_to_contexts $status_meter_contexts $water_meter_background_id

set ::water_meter [meter new -x [rescale_x_skin 2220] -y [rescale_y_skin 1310] -width [rescale_x_skin 280] -minvalue 0.0 -maxvalue [get_max_water_level] -get_meter_value get_water_level -get_target_value get_min_water_level -show_empty_full 1 _tick_frequency [expr ($::settings(water_level_sensor_max) * 0.9 * 0.25)] -needle_color $::color_water -label_color $::color_meter_grey -tick_color $::color_status_bar -contexts $status_meter_contexts -title [translate "Water"]]
add_de1_variable $status_meter_contexts -100 -100 -text "" -textvariable {[$::water_meter update]} 

# Temperature
set temperate_meter_background_id [.can create oval [rescale_x_skin -20] [rescale_y_skin 1230] [rescale_x_skin 420] [rescale_y_skin 1670] -fill $::color_status_bar -width 0 -state "hidden"]
add_visual_items_to_contexts $status_meter_contexts $temperate_meter_background_id

set ::temperature_meter [meter new -x [rescale_x_skin 60] -y [rescale_y_skin 1310] -width [rescale_x_skin 280] -minvalue 0.0 -maxvalue 100.0 -get_meter_value get_machine_temperature -get_target_value get_min_machine_temperature -tick_frequency 10.0 -label_frequency 20 -needle_color $::color_temperature -label_color $::color_meter_grey -tick_color $::color_status_bar -contexts $status_meter_contexts -title [translate "Head temperature"] -units [return_html_temperature_units]]
add_de1_variable $status_meter_contexts -100 -100 -text "" -textvariable {[$::temperature_meter update]} 

# Function bar
set status_function_contexts "off espresso_menu_profile espresso_menu_beans espresso_menu_grind espresso_menu_dose espresso_menu_ratio espresso_menu_yield espresso_menu_temperature espresso_done"

proc create_symbol_button {contexts x y label symbol color action} {
	set padding 20
	set button_id [create_symbol_box $contexts $x $y $label $symbol $color]
	add_de1_button $contexts $action [expr $x - $padding] [expr $y - $padding] [expr $x + 180 + $padding] [expr $y + 180 + $padding]
	return $button_id
}

rounded_rectangle $status_function_contexts .can [rescale_x_skin 500] [rescale_y_skin 1360] [rescale_x_skin 1010] [rescale_y_skin 2680] [rescale_x_skin 80] $::color_menu_background
set ::espresso_button_id [create_symbol_button $status_function_contexts 540 1400 [translate "espresso"] $::symbol_espresso $::color_menu_background {say [translate "espresso"] $::settings(sound_button_in); metric_jump_home }]
set ::steam_button_id [create_symbol_button $status_function_contexts 790 1400 [translate "steam"] $::symbol_steam $::color_menu_background {say [translate "steam"] $::settings(sound_button_in); do_start_steam}]

rounded_rectangle $status_function_contexts .can [rescale_x_skin 1550] [rescale_y_skin 1360] [rescale_x_skin 2060] [rescale_y_skin 2680] [rescale_x_skin 80] $::color_menu_background
set ::water_button_id [create_symbol_button $status_function_contexts 1590 1400 [translate "hot water"] $::symbol_water $::color_menu_background {say [translate "hot water"] $::settings(sound_button_in); do_start_water}]
set ::flush_button_id [create_symbol_button $status_function_contexts 1840 1400 [translate "flush"] $::symbol_flush $::color_menu_background {say [translate "flush"] $::settings(sound_button_in); do_start_flush}]

create_symbol_button $status_function_contexts 2080 40 [translate "settings"] $::symbol_settings $::color_menu_background { say [translate "settings"] $::settings(sound_button_in); show_settings; metric_load_current_profile }
create_symbol_button $status_function_contexts 2300 40 [translate "sleep"] $::symbol_power $::color_menu_background { say [translate "sleep"] $::settings(sound_button_in); start_sleep; metric_jump_home }


proc update_function_buttons {} {
	if { [can_start_espresso] } {
		.can itemconfigure $::espresso_button_id -fill $::color_text
	} else {
		.can itemconfigure $::espresso_button_id -fill $::color_grey_text
	}

	if { [can_start_water] } {
		.can itemconfigure $::water_button_id -fill $::color_text
	} else {
		.can itemconfigure $::water_button_id -fill $::color_grey_text
	}

	if { [can_start_steam] } {
		.can itemconfigure $::steam_button_id -fill $::color_text
	} else {
		.can itemconfigure $::steam_button_id -fill $::color_grey_text
	}	

	if { [can_start_flush] } {
		.can itemconfigure $::flush_button_id -fill $::color_text
	} else {
		.can itemconfigure $::flush_button_id -fill $::color_grey_text
	}
}
add_de1_variable $status_function_contexts -100 -100 -textvariable {[update_function_buttons]}


# status messages
set status_message_contexts "off espresso_menu_profile espresso_menu_beans espresso_menu_grind espresso_menu_dose espresso_menu_ratio espresso_menu_yield espresso_menu_temperature espresso_done steam water flush"
set ::connection_message_text_id [add_de1_text $status_message_contexts 80 160 -text "" -font $::font_setting_heading -fill $::color_temperature -anchor "w" ]
set ::temperature_message_text_id  [add_de1_text $status_message_contexts 200 1180 -text "" -font $::font_setting_heading -fill $::color_temperature -anchor "center" ]
set ::water_message_text_id  [add_de1_text $status_message_contexts 2360 1180 -text "" -font $::font_setting_heading -fill $::color_water -anchor "center" ]

proc set_status_message_visibility {} {
	if {![is_connected]} {
		.can itemconfigure $::connection_message_text_id -text [translate "not connected"]
		.can itemconfigure $::water_message_text_id -text ""
		.can itemconfigure $::temperature_message_text_id -text ""
	} else {
		.can itemconfigure $::connection_message_text_id -text ""

		if {![has_water]} {
			.can itemconfigure $::water_message_text_id -text [translate "refill water"]
		} else {
			.can itemconfigure $::water_message_text_id -text ""
		}

		if {[is_heating]} {
			.can itemconfigure $::temperature_message_text_id -text [translate "heating"]
		} else {
			.can itemconfigure $::temperature_message_text_id -text ""
		}
	}
}
add_de1_variable $status_message_contexts -100 -100 -text "" -textvariable {[set_status_message_visibility]}

# Display of machine state (mostly for debugging)
#add_de1_variable $status_message_contexts 2550 10 -anchor "ne" -text "" -font $::font_setting_heading -fill $::color_status_bar -textvariable {[get_status_text]} 
