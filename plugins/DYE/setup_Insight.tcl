
# Setup the UI integration with the Insight skin.

proc ::plugins::DYE::setup_ui_Insight {} {
	variable widgets 
	variable settings
		
	### INSIGHT HOME PAGE ###
	# Add an icon on the bottom-right Insight home page to open the demo page.
#	set widgets(launch_dye) [dui add dbutton {off off_zoomed off_zoomed_temperature espresso_3 espresso_3_zoomed espresso_3_zoomed_temperature} \
#		2400 900 2580 1050 -tags launch_dye -symbol $settings(describe_icon) -symbol_pos {0.4 0.5} -symbol_anchor center -symbol_justify center \
#		-command [list ::plugins::DYE::open -which_shot default -coords {2400 975} -anchor e] \
#		-longpress_cmd [::list ::plugins::DYE::open -which_shot dialog -coords \{2400 975\} -anchor e]]

	set widgets(launch_dye) [dui add dbutton {off off_zoomed off_zoomed_temperature espresso_3 espresso_3_zoomed espresso_3_zoomed_temperature} \
		2390 945 -bwidth 130 -bheight 120 -radius 30 -tags launch_dye -shape round -fill "#c1c5e4" \
		-symbol $settings(describe_icon) -symbol_pos {0.5 0.4} -symbol_anchor center -symbol_justify center -symbol_fill white \
		-label [translate DYE] -label_font_size 12 -label_pos {0.5 0.8} -label_anchor center -label_justify center -label_fill "#8991cc" \
		-label_width 130 -command [list ::plugins::DYE::open -which_shot default -coords {2400 975} -anchor e] \
		-label_font_family notosansuibold  -longpress_cmd [::list ::plugins::DYE::open -which_shot dialog -coords \{2400 975\} -anchor e] \
		-tap_pad {4 4 40 4} -page_title [translate {Select a shot to describe}]]
	
	### SCREENSAVER ###
	# Makes the left side of the app screensaver clickable so that you can describe your last shot without waking up 
	# the DE1. Note that this would overlap with the DSx plugin management option, if enabled. Provided by Damian.
	if { [string is true $settings(describe_from_sleep)] } {
		set sleep_describe_symbol $settings(describe_icon)
		set sleep_describe_button_coords {0 0 230 230}
	} else { 
		set sleep_describe_symbol ""
		set sleep_describe_button_coords {0 0 0 0}
	}
	set widgets(describe_from_sleep) [dui add dbutton saver {*}$sleep_describe_button_coords -tags saver_to_dye \
		-symbol $sleep_describe_symbol -symbol_pos {0.5 0.5} -symbol_font_size 45 -canvas_anchor center -justify center \
		-command [list ::plugins::DYE::open -which_shot last]]	
}

