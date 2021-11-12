
# Setup the UI integration with the Insight skin.

proc ::plugins::DYE::setup_ui_Insight {} {
	variable widgets 
	variable settings
		
	### INSIGHT HOME PAGE ###
	# Add an icon on the bottom-right Insight home page to open the demo page.
	set widgets(launch_dye) [dui add dbutton {off espresso_3} 2400 900 2580 1050 -tags launch_dye -symbol $settings(describe_icon) \
		-symbol_pos {0.4 0.5} -symbol_anchor center -symbol_justify center \
		-command [list ::plugins::DYE::open -which_shot default -coords {2400 975} -anchor e] \
		-longpress_cmd [::list ::plugins::DYE::open -which_shot dialog -coords \{2400 975\} -anchor e]]
		
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


