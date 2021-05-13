set espresso_contexts "off espresso_menu_profile espresso_menu_beans espresso_menu_grind espresso_menu_dose espresso_menu_ratio espresso_menu_yield espresso_menu_temperature"
set espresso_setting_contexts "off espresso_menu_grind espresso_menu_dose espresso_menu_ratio espresso_menu_yield espresso_menu_temperature"
add_background $espresso_contexts
add_page_title $espresso_contexts [translate "decent espresso"]

proc create_dropdown_button {contexts_closed context_open x y width label symbol color value action_open action_close} {
	set contexts "$context_open $contexts_closed"
	set font_value [get_font "Mazzard Regular" 22]

	rounded_rectangle $contexts .can [rescale_x_skin $x] [rescale_y_skin $y] [rescale_x_skin [expr $x + $width]] [rescale_y_skin [expr $y + 180]] [rescale_x_skin 30] $::color_menu_background
	create_symbol_box $contexts $x $y $label $symbol $color
	add_de1_variable $contexts [expr $x + ($width / 2.0)] [expr $y + 90] -text "" -font $font_value -fill $::color_text -anchor "center" -state "hidden" -textvariable $value

	set down_arrow_id [.can create line [rescale_x_skin [expr $x + $width - 130]] [rescale_y_skin [expr $y + 70]] [rescale_x_skin [expr $x + $width - 90]] [rescale_y_skin [expr $y + 110]] [rescale_x_skin [expr $x + $width - 50]] [rescale_y_skin [expr $y + 70]] -width [rescale_x_skin 18] -fill $::color_text -state "hidden"]
	add_visual_items_to_contexts $contexts_closed $down_arrow_id
	
	set up_arrow_id [.can create line [rescale_x_skin [expr $x + $width - 130]] [rescale_y_skin [expr $y + 110]] [rescale_x_skin [expr $x + $width - 90]] [rescale_y_skin [expr $y + 70]] [rescale_x_skin [expr $x + $width - 50]] [rescale_y_skin [expr $y + 110]] -width [rescale_x_skin 18] -fill $::color_text -state "hidden"]
	add_visual_items_to_contexts $context_open $up_arrow_id

	add_de1_button $contexts_closed $action_open $x $y [expr $x + $width] [expr $y + 180]
	add_de1_button $context_open $action_close $x $y [expr $x + $width] [expr $y + 180]
}

proc create_2value_label {contexts x y value1 value2} {
	set font_value [get_font "Mazzard Regular" 32]
	set font_value_small [get_font "Mazzard Regular" 22]

	add_de1_variable $contexts $x $y -text "" -font $font_value -fill $::color_text -anchor "e" -state "hidden" -textvariable $value1
	add_de1_variable $contexts $x [expr $y + 38] -text "" -font $font_value_small -fill $::color_text -anchor "sw" -state "hidden" -textvariable $value2
}


proc create_2value_button {contexts x y width label symbol color value1 value2 action} {
	set font_value [get_font "Mazzard Regular" 32]
	set font_value_small [get_font "Mazzard Regular" 22]

	rounded_rectangle $contexts .can [rescale_x_skin $x] [rescale_y_skin $y] [rescale_x_skin [expr $x + $width]] [rescale_y_skin [expr $y + 180]] [rescale_x_skin 30] $::color_menu_background
	create_symbol_box $contexts $x $y $label $symbol $color
	create_2value_label $contexts [expr $x + 90 + ($width / 2.0)] [expr $y + 90] $value1 $value2

	add_de1_button $contexts $action $x $y [expr $x + $width] [expr $y + 180]
}

proc create_arrow_button { contexts x y size thickness direction action } {
	set dx [expr $size * 0.5]
	set dy [expr $size * 0.25]
	set margin 20
	set arrow_id [.can create line [rescale_x_skin [expr $x - $dx]] [rescale_y_skin [expr $y + ($dy * $direction)]] [rescale_x_skin $x] [rescale_y_skin [expr $y - ($dy * $direction)]] [rescale_x_skin [expr $x + $dx]] [rescale_y_skin [expr $y + ($dy * $direction)]] -width [rescale_x_skin $thickness] -fill $::color_arrow -state hidden]
	add_visual_items_to_contexts $contexts $arrow_id
	add_de1_button $contexts $action [expr $x - $dx -$margin] [expr $y - $dy - $margin] [expr $x + $dx + $margin] [expr $y + $dy + $margin]
}

proc create_arrow_buttons { contexts x y varname smalldelta largedelta minval maxval after_adjust_action} {
	rounded_rectangle $contexts .can [rescale_x_skin $x] [rescale_y_skin [expr $y - 290]] [rescale_x_skin [expr $x + 400]] [rescale_y_skin [expr $y + 290]] [rescale_x_skin 80] $::color_menu_background
	create_arrow_button $contexts [expr $x + 200] [expr $y - 220] 100 12 1 "say \"up\" $::settings(sound_button_in); adjust_setting $varname $largedelta $minval $maxval; $after_adjust_action"
	create_arrow_button $contexts [expr $x + 200] [expr $y - 140] 60 8 1 "say \"up\" $::settings(sound_button_in); adjust_setting $varname $smalldelta $minval $maxval; $after_adjust_action"
	create_arrow_button $contexts [expr $x + 200] [expr $y + 140] 60 8 -1 "say \"down\" $::settings(sound_button_in); adjust_setting $varname -$smalldelta $minval $maxval; $after_adjust_action"
	create_arrow_button $contexts [expr $x + 200] [expr $y + 220] 100 12 -1 "say \"down\" $::settings(sound_button_in); adjust_setting $varname -$largedelta $minval $maxval; $after_adjust_action"
}

create_dropdown_button "$espresso_setting_contexts espresso_menu_profile" "espresso_menu_beans" 80 260 1170 [translate "beans"] $::symbol_bean $::color_dose {$::settings(bean_brand)\n$::settings(bean_type)} {say [translate "beans"] $::settings(sound_button_in); metric_jump_to "espresso_menu_beans"; focus $::metric_bean_name_editor} {say [translate "close"] $::settings(sound_button_in); metric_jump_to "off"}

rounded_rectangle "espresso_menu_beans" .can [rescale_x_skin 80] [rescale_y_skin 470] [rescale_x_skin 2480] [rescale_y_skin 1200] [rescale_x_skin 30] $::color_menu_background
add_de1_text "espresso_menu_beans" 130 560 -text [translate "Roaster name:"] -font [get_font "Mazzard Regular" 22] -fill $::color_text -anchor "w" -state "hidden"
add_de1_widget "espresso_menu_beans" entry 780 530 {
		set ::metric_bean_name_editor $widget
		bind $widget <Leave> { hide_android_keyboard; metric_bean_details_changed }
		bind $widget <Return> { hide_android_keyboard; metric_bean_details_changed }
	} -width [expr {int(22 * $::globals(entry_length_multiplier))}]  -font [get_font "Mazzard Regular" 22] -borderwidth 1 -bg $::color_menu_background -foreground $::color_text -textvariable ::settings(bean_brand) -relief flat -highlightthickness 1 -selectbackground $::color_background 

add_de1_text "espresso_menu_beans" 130 680 -text [translate "Bean type:"] -font [get_font "Mazzard Regular" 22] -fill $::color_text -anchor "w" -state "hidden"
add_de1_widget "espresso_menu_beans" entry 780 650 {
		set ::metric_bean_name_editor $widget
		bind $widget <Leave> { hide_android_keyboard; metric_bean_details_changed }
		bind $widget <Return> { hide_android_keyboard; metric_bean_details_changed }
	} -width [expr {int(22 * $::globals(entry_length_multiplier))}]  -font [get_font "Mazzard Regular" 22] -borderwidth 1 -bg $::color_menu_background -foreground $::color_text -textvariable ::settings(bean_type) -relief flat -highlightthickness 1 -selectbackground $::color_background 


create_dropdown_button "$espresso_setting_contexts espresso_menu_beans" "espresso_menu_profile" 1310 260 1170 [translate "profile"] $::symbol_menu $::color_profile {$::settings(profile_title)} {say [translate "profile"] $::settings(sound_button_in); fill_metric_profiles_listbox; metric_jump_to "espresso_menu_profile"; set_metric_profiles_scrollbar_dimensions; select_metric_profile} {say [translate "close"] $::settings(sound_button_in); metric_jump_to "off"}

proc get_profile_title { profile_filename } {
	set file_path "[homedir]/profiles/$profile_filename.tcl"
	set file_data [encoding convertfrom utf-8 [read_binary_file $file_path]]
	catch {
		array set profile_data $file_data
	}

	if {[array exists profile_data] == 0} {
		return ""
	}

	set title $profile_data(profile_title)
	set title [translate $title]

	return $title
}

proc metric_profile_selected {} {
	if {[ifexists ::metric_ignore_profile_selection] == 1} { return }

	set selected_index [$::globals(metric_profiles_listbox) curselection]
	if {$selected_index != ""} {
		metric_load_profile $::profile_number_to_directory($selected_index)
	}
	metric_jump_to "off"
}

# select the listbox item corresponding to the current profile
proc select_metric_profile {} {
	set itemcount [array size profile_number_to_directory]
	if {$itemcount == 0} {
		return
	}

	set selected_index 0
	for {set index 0} {$index < $itemcount} {incr index} {
		if {$::profile_number_to_directory($selected_index) == $::settings(profile_filename)} {
			set selected_index $index
			continue
		}
	}

	set widget $::globals(metric_profiles_listbox)

	set ::metric_ignore_profile_selection 1
	$widget selection set $selected_index
	unset -nocomplain ::metric_ignore_profile_selection

	$widget see $profile_index
}

# populate the listbox with profiles
proc fill_metric_profiles_listbox { } {
	fill_specific_profiles_listbox $::globals(metric_profiles_listbox) "" 0
	select_metric_profile
}

rounded_rectangle "espresso_menu_profile" .can [rescale_x_skin 80] [rescale_y_skin 470] [rescale_x_skin 2480] [rescale_y_skin 1200] [rescale_x_skin 30] $::color_menu_background
add_de1_widget "espresso_menu_profile" listbox 105 500 {
		set ::globals(metric_profiles_listbox) $widget
	 	fill_metric_profiles_listbox
		bind $::globals(metric_profiles_listbox) <<ListboxSelect>> ::metric_profile_selected
	 } -background $::color_menu_background -foreground $::color_text -selectbackground $::color_text -selectforeground $::color_background -font [get_font "Mazzard Regular" 32] -bd 0 -height [expr {int(8 * $::globals(listbox_length_multiplier))}] -width 44 -borderwidth 0 -selectborderwidth 0  -relief flat -highlightthickness 0 -selectmode single -xscrollcommand {scale_prevent_horiz_scroll $::globals(metric_profiles_listbox)} -yscrollcommand {scale_scroll_new $::globals(metric_profiles_listbox) ::metric_profiles_slider}   

set ::metric_profiles_slider 0

# draw the scrollbar off screen so that it gets resized and moved to the right place on the first draw
set ::metric_profiles_scrollbar [add_de1_widget "espresso_menu_profile" scale 10000 1 {} -from 0 -to 1 -bigincrement 0.2 -background $::color_menu_background -borderwidth 1 -showvalue 0 -resolution .01 -length [rescale_x_skin 400] -width [rescale_y_skin 150] -variable ::metric_profiles_slider -font Helv_10_bold -sliderlength [rescale_x_skin 125] -relief flat -command {listbox_moveto $::globals(metric_profiles_listbox) $::metric_profiles_slider} -foreground $::color_menu_background -troughcolor $::color_background -borderwidth 0 -highlightthickness 0]

proc set_metric_profiles_scrollbar_dimensions {} {
	# set the height of the scrollbar to be the same as the listbox
	$::metric_profiles_scrollbar configure -length [winfo height $::globals(metric_profiles_listbox)]
	set coords [.can coords $::globals(metric_profiles_listbox) ]
	set newx [expr {[winfo width $::globals(metric_profiles_listbox)] + [lindex $coords 0]}]
	.can coords $::metric_profiles_scrollbar "$newx [lindex $coords 1]"
}



proc get_exponent {value} {
	set value1 [format "%.1f" $value]
	return [lindex [split $value1 "."] 1]
}
proc get_mantissa {value} {
	set value1 [format "%.1f" $value]
	return [lindex [split $value1 "."] 0]
}

# config
set x 80
set y 800

create_arrow_buttons "espresso_menu_grind" $x $y "::settings(grinder_setting)" 0.5 1 $::metric_setting_grind_min $::metric_setting_grind_max metric_grind_changed
create_2value_button $espresso_setting_contexts $x [expr $y -90] 400 [translate "grind"] $::symbol_grind $::color_grind {[get_mantissa $::settings(grinder_setting)]} {.[get_exponent $::settings(grinder_setting)]} {say [translate "grind"] $::settings(sound_button_in); metric_jump_to "espresso_menu_grind"}
add_de1_button "espresso_menu_grind" {say [translate "close"] $::settings(sound_button_in); metric_jump_to "off"} $x [expr $y - 90] [expr $x + 400] [expr $y + 90]
incr x 500

create_arrow_buttons "espresso_menu_dose" $x $y "::settings(grinder_dose_weight)" 0.1 1 $::metric_setting_dose_min $::metric_setting_dose_max metric_dose_changed
create_2value_button $espresso_setting_contexts $x [expr $y -90] 400 [translate "dose"] $::symbol_bean $::color_dose {[get_mantissa $::settings(grinder_dose_weight)]} {.[get_exponent $::settings(grinder_dose_weight)]g} {say [translate "dose"] $::settings(sound_button_in); metric_jump_to "espresso_menu_dose"}
add_de1_button "espresso_menu_dose" {say [translate "close"] $::settings(sound_button_in); metric_jump_to "off"} $x [expr $y - 90] [expr $x + 400] [expr $y + 90]
incr x 500

create_arrow_buttons "espresso_menu_ratio" $x $y "::metric_ratio" 0.1 1 $::metric_setting_ratio_min $::metric_setting_ratio_max metric_ratio_changed
create_2value_button $espresso_setting_contexts $x [expr $y -90] 400 [translate "ratio"] $::symbol_ratio $::color_ratio {[get_mantissa $::metric_ratio]} {.[get_exponent $::metric_ratio]x} {say [translate "ratio"] $::settings(sound_button_in); metric_jump_to "espresso_menu_ratio"}
add_de1_button "espresso_menu_ratio" {say [translate "close"] $::settings(sound_button_in); metric_jump_to "off"} $x [expr $y - 90] [expr $x + 400] [expr $y + 90]
incr x 500

create_arrow_buttons "espresso_menu_yield" $x $y "::metric_yield" 0.1 1 $::metric_setting_yield_min $::metric_setting_yield_max metric_yield_changed
create_2value_button $espresso_setting_contexts $x [expr $y -90] 400 [translate "yield"] $::symbol_espresso $::color_yield {[get_mantissa $::metric_yield]} {.[get_exponent $::metric_yield]g} {say [translate "yield"] $::settings(sound_button_in); metric_jump_to "espresso_menu_yield"}
add_de1_button "espresso_menu_yield" {say [translate "close"] $::settings(sound_button_in); metric_jump_to "off"} $x [expr $y - 90] [expr $x + 400] [expr $y + 90]
incr x 500

set ::metric_temperature_delta 0
create_arrow_buttons "espresso_menu_temperature" $x $y "::metric_temperature_delta" 0.5 1 -1 1 metric_temperature_changed
create_2value_button $espresso_setting_contexts $x [expr $y -90] 400 [translate "temp"] $::symbol_temperature $::color_temperature {[get_mantissa $::settings(espresso_temperature)]} {.[get_exponent $::settings(espresso_temperature)]\u00B0C} {say [translate "temperature"] $::settings(sound_button_in); metric_jump_to "espresso_menu_temperature"}
add_de1_button "espresso_menu_temperature" {say [translate "close"] $::settings(sound_button_in); metric_jump_to "off"} $x [expr $y - 90] [expr $x + 400] [expr $y + 90]


set ::espresso_action_button_id [create_action_button $espresso_setting_contexts 1280 1340 [translate "start"] $::font_action_label $::color_text $::symbol_espresso $::font_action_button $::color_action_button_start $::color_action_button_text {say [translate {start}] $::settings(sound_button_in); do_start_espresso} ""]

proc update_espresso_button {} {
	if { [can_start_espresso] } {
		update_button_color $::espresso_action_button_id $::color_action_button_start
	} else {
		update_button_color $::espresso_action_button_id $::color_action_button_disabled
	}
}
add_de1_variable $espresso_setting_contexts -100 -100 -textvariable {[update_espresso_button]} 

#create_button "off" 2280 60 2480 180 [translate "debug"] $::font_button $::color_button $::color_button_text { say [translate "debug"] $::settings(sound_button_in); metric_jump_to "debug"}
